import SwiftUI
import FarmaciaKit

// MARK: - Transfer Product Sheet
//
// Opens on every pick or scan in Transferencias: the product, this store's stock and
// expiry dates, and how many to send (the big −/+ stepper, up to the stock). A re-pick
// opens at its listed quantity and saves over it. Swiping it down changes nothing.
// tasks/transfer-sheet-epic.md

private enum SheetField: Hashable { case quantity }

struct TransferProductSheet: View {
    let product: Product
    let start: Int
    /// "Agregar", or "Guardar" for a product already in the list.
    let actionTitle: String
    let onSave: (Int) -> Void

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var quantity: Int?
    /// This store's lots; nil while loading.
    @State private var lots: [TransferLots.Row]?
    @State private var lotsFailed = false
    @FocusState private var focusedField: SheetField?

    init(product: Product, start: Int, actionTitle: String, onSave: @escaping (Int) -> Void) {
        self.product = product
        self.start = start
        self.actionTitle = actionTitle
        self.onSave = onSave
        _quantity = State(initialValue: start)
    }

    /// This store's stock (its lots); `quantity` on Product is piezas por caja.
    private var available: Int { max(0, product.totalInventory ?? 0) }

    private var issue: String? { TransferDraft.lineIssue(quantity: quantity ?? 0, available: available) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Photo beside the text, so the stepper and the expiry dates fit at medium height.
                    HStack(spacing: DS.Spacing.m) {
                        CachedProductImage(url: product.squareImageUrl, targetSize: CGSize(width: 88, height: 88)) {
                            Image(systemName: "shippingbox")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 88, height: 88)
                        .background(.fill.tertiary, in: .rect(cornerRadius: DS.Radius.m))
                        .clipShape(.rect(cornerRadius: DS.Radius.m))
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(product.displayName)
                                .font(.headline)
                            if let sku = product.sku, !sku.isEmpty {
                                Text("SKU \(sku)").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(available > 0 ? "Hay \(available) aquí" : "Sin existencias aquí")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    QuantityStepper(value: $quantity, unit: "unidades", focus: $focusedField, field: .quantity,
                                    maximum: TransferDraft.stepRange(available: available).upperBound)
                        .frame(maxWidth: .infinity)
                    if let issue {
                        StatusLabel(issue, tone: .critical)
                    }
                }

                Section("Caducidades aquí") {
                    if lotsFailed {
                        StatusLabel("No se pudieron cargar las caducidades.", tone: .caution)
                    } else if let lots {
                        if lots.isEmpty {
                            Text("Sin existencias aquí").foregroundStyle(.secondary)
                        }
                        ForEach(Array(lots.enumerated()), id: \.offset) { _, row in
                            StatusLabel(row.text, tone: row.tone)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Transferir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) {
                        onSave(quantity ?? 0)
                        dismiss()
                    }
                    .disabled(issue != nil)
                }
            }
            .task { await loadLots() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func loadLots() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        do {
            let response: APIResponse<[CurrentLot]> = try await APIClient.shared.request(
                endpoint: .inventoryLots,
                queryParams: ["productId": product.id, "locationId": locationId]
            )
            guard !Task.isCancelled else { return }
            lots = TransferLots.rows(response.data ?? [], onHand: available)
        } catch {
            guard !NetworkError.isCancellation(error) else { return }
            lotsFailed = true
        }
    }
}
