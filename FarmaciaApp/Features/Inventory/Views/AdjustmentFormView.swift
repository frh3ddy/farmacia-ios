import SwiftUI
import FarmaciaKit

// MARK: - Adjustment Form View

struct AdjustmentFormView: View {
    let adjustmentType: AdjustmentType
    @ObservedObject var viewModel: InventoryViewModel

    /// When set, the product is pre-selected and locked (coming from ProductDetailView).
    let preSelectedProduct: Product?
    /// Called after a successful adjustment so the parent can refresh data
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var selectedProduct: Product?
    @State private var showProductPicker = false
    @State private var quantity: Int?
    @State private var newCount: Int?
    @State private var unitCost: Double?
    @State private var reason = ""
    @State private var notes = ""
    @FocusState private var isFieldFocused: Bool
    /// One per adjustment being entered: a retry (or the offline queue's replay) reuses it.
    @State private var clientRequestId = UUID().uuidString
    /// Count types compare against stock loaded for the current location when the form opens,
    /// never the product snapshot the form was handed.
    @State private var liveStock: Int?
    @State private var liveStockFailed = false
    private let network = NetworkMonitor.shared

    /// Convenience initializer for standalone use (no pre-selected product)
    init(adjustmentType: AdjustmentType, viewModel: InventoryViewModel) {
        self.adjustmentType = adjustmentType
        self.viewModel = viewModel
        self.preSelectedProduct = nil
        self.onComplete = nil
    }

    /// Initializer for use from ProductDetailView with a pre-selected product
    init(adjustmentType: AdjustmentType, viewModel: InventoryViewModel, preSelectedProduct: Product, onComplete: (() -> Void)? = nil) {
        self.adjustmentType = adjustmentType
        self.viewModel = viewModel
        self.preSelectedProduct = preSelectedProduct
        self.onComplete = onComplete
    }

    private var isProductLocked: Bool {
        preSelectedProduct != nil
    }

    private var countChange: Int? {
        CountCorrection.preview(counted: newCount, current: liveStock)
    }

    private var asksForCost: Bool {
        AdjustmentCost.asksForCost(
            isNegative: adjustmentType.isNegative,
            isVariable: adjustmentType.isVariable,
            countChange: countChange
        )
    }

    private var isValid: Bool {
        guard selectedProduct != nil else { return false }
        if adjustmentType.isVariable {
            return network.isConnected && countChange != nil
        }
        return (quantity ?? 0) != 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Producto") {
                    if isProductLocked {
                        // Product is pre-selected and locked — show as info, not a button
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedProduct?.displayName ?? "")
                                    .foregroundStyle(.primary)
                                if let sku = selectedProduct?.sku {
                                    Text("SKU: \(sku)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !adjustmentType.isVariable, let stock = selectedProduct?.totalInventory {
                                    Text("Stock actual: \(stock) unidades")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            showProductPicker = true
                        } label: {
                            HStack {
                                if let product = selectedProduct {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName)
                                            .foregroundStyle(.primary)
                                        if let sku = product.sku {
                                            Text("SKU: \(sku)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                } else {
                                    Text("Seleccionar Producto")
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Cantidad") {
                    if adjustmentType.isVariable {
                        HStack {
                            Text("Cantidad Actual")
                            Spacer()
                            if let liveStock {
                                Text("\(liveStock)")
                                    .foregroundStyle(.secondary)
                            } else if !network.isConnected {
                                Text("Requiere conexión")
                                    .foregroundStyle(.orange)
                            } else if liveStockFailed {
                                Button("Reintentar") {
                                    Task { await loadLiveStock() }
                                }
                            } else if selectedProduct != nil {
                                ProgressView()
                            }
                        }

                        HStack {
                            Text("Nueva Cantidad")
                            Spacer()
                            TextField("0", value: $newCount, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($isFieldFocused)
                        }

                        if let delta = countChange {
                            Text(delta > 0
                                 ? "Esto agregará \(delta) unidades al inventario"
                                 : "Esto eliminará \(abs(delta)) unidades del inventario")
                                .font(.caption)
                                .foregroundStyle(delta > 0 ? .green : .red)
                        }
                    } else {
                        HStack {
                            Text("Cantidad")
                            Spacer()
                            TextField("0", value: $quantity, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .focused($isFieldFocused)
                        }

                        if adjustmentType.isNegative {
                            Text("Esto eliminará \(quantity ?? 0) unidades del inventario")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Esto agregará \(quantity ?? 0) unidades al inventario")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                if asksForCost {
                    Section {
                        HStack {
                            Text("Costo Unitario")
                            TextField("0.00", value: $unitCost, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isFieldFocused)
                            Text("MXN")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Opcional. Si lo dejas vacío se usa el último costo del producto.")
                    }
                }

                Section("Detalles") {
                    TextField("Razón", text: $reason)
                        .focused($isFieldFocused)
                    TextField("Notas (opcional)", text: $notes)
                        .focused($isFieldFocused)
                }
            }
            .navigationTitle(adjustmentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardTopSpacing(24, isActive: isFieldFocused)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        // Set before the Task runs, so a second tap can't slip in first
                        guard !viewModel.isSubmitting else { return }
                        viewModel.isSubmitting = true
                        Task { await saveAdjustment() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .sheet(isPresented: $showProductPicker) {
                ProductPickerView(
                    products: viewModel.products,
                    selectedProduct: $selectedProduct,
                    isLoading: viewModel.isLoadingProducts
                )
            }
            .alert("No se pudo guardar", isPresented: $viewModel.showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.saveError ?? "")
            }
            .onAppear {
                // Pre-select product if provided (from ProductDetailView context)
                if let product = preSelectedProduct, selectedProduct == nil {
                    selectedProduct = product
                }
            }
            // Reloads when the product or location changes, or the connection comes back
            .task(id: [selectedProduct?.id, authManager.currentLocation?.id, String(network.isConnected)]) {
                await loadLiveStock()
            }
        }
    }

    private func loadLiveStock() async {
        liveStock = nil
        liveStockFailed = false
        guard adjustmentType.isVariable, network.isConnected,
              let product = selectedProduct,
              let locationId = authManager.currentLocation?.id else { return }

        do {
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .getProduct(id: product.id),
                queryParams: ["locationId": locationId]
            )
            // A superseded load (product, location or connection changed) must not
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
        guard let product = selectedProduct,
              let locationId = authManager.currentLocation?.id,
              let adjustedQty else {
            viewModel.isSubmitting = false
            return
        }

        let success = await viewModel.createAdjustment(
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

        if success {
            onComplete?()
            dismiss()
        }
    }
}
