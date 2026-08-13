import SwiftUI

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
    @State private var reason = ""
    @State private var notes = ""

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

    private var isValid: Bool {
        selectedProduct != nil &&
        (quantity ?? 0) != 0
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
                                if let stock = selectedProduct?.totalInventory {
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
                    HStack {
                        Text("Cantidad")
                        Spacer()
                        TextField("0", value: $quantity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    if adjustmentType.isVariable {
                        Text("Ingrese positivo para agregar, negativo para quitar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if adjustmentType.isNegative {
                        Text("Esto eliminará \(quantity ?? 0) unidades del inventario")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Esto agregará \(quantity ?? 0) unidades al inventario")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section("Detalles") {
                    TextField("Razón", text: $reason)
                    TextField("Notas (opcional)", text: $notes)
                }
            }
            .navigationTitle(adjustmentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .keyboardTopSpacing(24)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
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
            .onAppear {
                // Pre-select product if provided (from ProductDetailView context)
                if let product = preSelectedProduct, selectedProduct == nil {
                    selectedProduct = product
                }
            }
        }
    }

    private func saveAdjustment() async {
        guard let product = selectedProduct,
              let qty = quantity,
              let locationId = authManager.currentLocation?.id else { return }

        // For negative adjustment types, ensure quantity is positive (API handles sign)
        let adjustedQty = adjustmentType.isNegative ? abs(qty) : qty

        let success = await viewModel.createAdjustment(
            type: adjustmentType,
            productId: product.id,
            quantity: adjustedQty,
            locationId: locationId,
            reason: reason.isEmpty ? nil : reason,
            notes: notes.isEmpty ? nil : notes
        )

        if success {
            onComplete?()
            dismiss()
        }
    }
}
