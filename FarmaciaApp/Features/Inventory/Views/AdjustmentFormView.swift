import SwiftUI
import FarmaciaKit

// MARK: - Adjustment Form View
//
// On the form kit (tasks/design-system-epic.md): product summary, AmountField,
// .formKeyboard, Guardar → spinner while saving.

struct AdjustmentFormView: View {
    let adjustmentType: AdjustmentType
    @ObservedObject var viewModel: InventoryViewModel

    /// The product being adjusted (the form opens from its detail screen).
    let product: Product
    /// Called after a successful adjustment so the parent can refresh data
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var quantity: Int?
    @State private var newCount: Int?
    @State private var unitCost: Double?
    /// Set when the API refused for lack of a cost on record; reveals the cost field.
    @State private var costRequired = false
    @State private var reason = ""
    @State private var notes = ""
    private enum Field: Hashable { case quantity, newCount, unitCost, reason, notes }
    @FocusState private var focusedField: Field?

    /// Top to bottom, skipping rows that aren't shown.
    private var focusOrder: FocusOrder<Field> {
        FocusOrder([adjustmentType.isVariable ? .newCount : .quantity]
            + (asksForCost ? [.unitCost] : [])
            + [.reason, .notes])
    }
    /// One per adjustment being entered: a retry (or the offline queue's replay) reuses it.
    @State private var clientRequestId = UUID().uuidString
    /// Stock loaded for the current location when the form opens (online): counts compare
    /// against it, never the product snapshot the form was handed; other types preview from it.
    @State private var liveStock: Int?
    @State private var liveStockFailed = false
    private let network = NetworkMonitor.shared

    private var countChange: Int? {
        CountCorrection.preview(counted: newCount, current: liveStock)
    }

    private var asksForCost: Bool {
        AdjustmentCost.asksForCost(
            isNegative: adjustmentType.isNegative,
            isVariable: adjustmentType.isVariable,
            countChange: countChange,
            costRequired: costRequired
        )
    }

    /// What saving does to this store's stock, shown before Guardar
    /// ("Centro · 42 → 39 (−3)"). Counts use the live stock; other types too
    /// when it has loaded, else the product's last known stock — so a removal
    /// past it only warns. The API checks against its own stock.
    private var stockImpact: StockImpact? {
        if adjustmentType.isVariable {
            return StockImpact(before: liveStock, change: countChange)
        }
        guard let quantity else { return nil }
        let change = adjustmentType.isNegative ? -abs(quantity) : abs(quantity)
        return StockImpact(before: currentStock, change: change)
    }

    private var isValid: Bool {
        if adjustmentType.isVariable {
            return network.isConnected && countChange != nil
        }
        return (quantity ?? 0) != 0
    }

    /// This store's stock: the live fetch when it's in, else the cached product's.
    private var currentStock: Int? { liveStock ?? product.totalInventory }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProductSummaryRow(product: product, stock: adjustmentType.isVariable ? nil : currentStock)
                }

                Section {
                    if adjustmentType.isVariable {
                        LabeledContent("Cantidad actual") {
                            if let liveStock {
                                Text("\(liveStock)")
                            } else if !network.isConnected {
                                Text("Requiere conexión")
                                    .foregroundStyle(Tone.caution.color)
                            } else if liveStockFailed {
                                Button("Reintentar") {
                                    Task { await loadLiveStock() }
                                }
                            } else {
                                ProgressView()
                            }
                        }

                        AmountField(
                            "Nueva cantidad",
                            unit: "UDS",
                            value: $newCount,
                            focus: $focusedField,
                            field: .newCount
                        )
                    } else {
                        AmountField(
                            "Cantidad",
                            unit: "UDS",
                            value: $quantity,
                            focus: $focusedField,
                            field: .quantity
                        )
                    }
                } footer: {
                    if let impact = stockImpact {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            StatusLabel(
                                [authManager.currentLocation?.name, impact.summary]
                                    .compactMap { $0 }.joined(separator: " · "),
                                tone: impact.tone,
                                systemImage: impact.change > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                            )
                            .monospacedDigit()
                            if impact.exceedsStock {
                                StatusLabel("Es más de lo que hay en existencia.", tone: .caution)
                            }
                        }
                    }
                }

                if asksForCost {
                    Section {
                        AmountField(
                            "Costo unitario",
                            unit: "MXN",
                            value: $unitCost,
                            focus: $focusedField,
                            field: .unitCost
                        )
                    } footer: {
                        Text("Este producto no tiene un costo anterior registrado.")
                    }
                }

                Section {
                    LabeledContent("Razón") {
                        TextField("Razón", text: $reason, prompt: Text("Opcional"))
                            .multilineTextAlignment(.trailing)
                            .formField(.reason, focus: $focusedField)
                    }
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                        .formField(.notes, focus: $focusedField)
                }
            }
            // No edits while a save is in flight.
            .disabled(viewModel.isSubmitting)
            .navigationTitle(adjustmentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .formKeyboard(focus: $focusedField, order: focusOrder)
            .interactiveDismissDisabled(viewModel.isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    // While saving, the button becomes a spinner in its place.
                    if viewModel.isSubmitting {
                        ProgressView()
                            .accessibilityLabel("Guardando")
                    } else {
                        Button("Guardar") {
                            // Set before the Task runs, so a second tap can't slip in first
                            guard !viewModel.isSubmitting else { return }
                            viewModel.isSubmitting = true
                            Task { await saveAdjustment() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .alert("No se pudo guardar", isPresented: $viewModel.showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.saveError ?? "")
            }
            // Reloads when the location changes or the connection comes back
            .task(id: [authManager.currentLocation?.id, String(network.isConnected)]) {
                await loadLiveStock()
            }
        }
    }

    private func loadLiveStock() async {
        liveStock = nil
        liveStockFailed = false
        guard network.isConnected,
              let locationId = authManager.currentLocation?.id else { return }

        do {
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .getProduct(id: product.id),
                queryParams: ["locationId": locationId]
            )
            // A superseded load (location or connection changed) must not
            // overwrite the newer one's state — URLSession may finish or fail anyway.
            guard !Task.isCancelled else { return }
            liveStock = response.data.totalInventory ?? 0
        } catch {
            guard !Task.isCancelled else { return }
            liveStockFailed = true
        }
    }

    private func saveAdjustment() async {
        // Variable types (count correction) send the counted total and the
        // previewed change; the API derives the real change from its own stock.
        // Fixed-sign types only ever collect a magnitude — the server
        // re-derives the correct sign for those, so plain abs() is enough.
        let adjustedQty: Int?
        if adjustmentType.isVariable {
            adjustedQty = countChange
        } else {
            adjustedQty = quantity.map(abs)
        }
        guard let locationId = authManager.currentLocation?.id,
              let adjustedQty else {
            viewModel.isSubmitting = false
            return
        }

        let outcome = await viewModel.createAdjustment(
            type: adjustmentType,
            productId: product.id,
            quantity: adjustedQty,
            countedQuantity: adjustmentType == .countCorrection ? newCount : nil,
            // A cost typed before the count turned into a removal isn't sent
            unitCost: asksForCost ? unitCost : nil,
            locationId: locationId,
            reason: reason.isEmpty ? nil : reason,
            notes: notes.isEmpty ? nil : notes,
            clientRequestId: clientRequestId
        )

        switch outcome {
        case .saved:
            onComplete?()
            dismiss()
        case .costRequired:
            costRequired = true
        case .failed:
            break
        }
    }
}
