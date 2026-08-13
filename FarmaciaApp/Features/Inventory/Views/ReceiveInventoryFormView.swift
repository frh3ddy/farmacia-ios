import SwiftUI

// MARK: - Receive Inventory Form View

struct ReceiveInventoryFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel

    /// When set, the product is pre-selected and locked (coming from ProductDetailView).
    /// When nil, the user picks a product from the full list (standalone inventory flow).
    let preSelectedProduct: Product?
    /// Called after a successful receive so the parent can refresh data
    var onComplete: (() -> Void)?

    @State private var selectedProduct: Product?
    @State private var showProductPicker = false
    @State private var quantity: Int?
    @State private var unitCost: Double?
    @State private var updateSellingPrice = false
    @State private var newSellingPrice: Double?
    @State private var invoiceNumber = ""
    @State private var batchNumber = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year
    @State private var selectedSupplier: Supplier?
    @State private var showSupplierPicker = false
    @State private var notes = ""

    // Supplier intelligence
    @State private var productSuppliers: [ProductSupplier] = []
    @State private var isLoadingSuppliers = false
    @State private var supplierLastCost: Double?
    @State private var supplierCostNote: String?

    /// Convenience initializer for standalone use (no pre-selected product)
    init(viewModel: InventoryViewModel) {
        self.viewModel = viewModel
        self.preSelectedProduct = nil
        self.onComplete = nil
    }

    /// Initializer for use from ProductDetailView with a pre-selected product
    init(viewModel: InventoryViewModel, preSelectedProduct: Product, onComplete: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.preSelectedProduct = preSelectedProduct
        self.onComplete = onComplete
    }

    private var isProductLocked: Bool {
        preSelectedProduct != nil
    }

    private var isValid: Bool {
        selectedProduct != nil &&
        (quantity ?? 0) > 0 &&
        (unitCost ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Product Selection
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
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Standard product picker button
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

                // Quantity & Cost
                Section("Cantidad y Costo") {
                    HStack {
                        Text("Cantidad")
                        Spacer()
                        TextField("0", value: $quantity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Costo Unitario")
                        Spacer()
                        Text("$")
                        TextField("0.00", value: $unitCost, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    if let qty = quantity, qty > 0,
                       let cost = unitCost, cost > 0 {
                        HStack {
                            Text("Costo Total")
                            Spacer()
                            Text("$\(String(format: "%.2f", Double(qty) * cost))")
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Selling Price Update (Optional)
                Section {
                    Toggle("Actualizar Precio de Venta", isOn: $updateSellingPrice)

                    if updateSellingPrice {
                        HStack {
                            Text("Nuevo Precio")
                            Spacer()
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: $newSellingPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("MXN")
                                .foregroundStyle(.secondary)
                        }

                        // Show current price if available
                        if let currentPrice = selectedProduct?.sellingPrice {
                            HStack {
                                Text("Precio Actual")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("$\(String(format: "%.2f", currentPrice)) MXN")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                        }

                        // Margin preview
                        if let cost = unitCost, cost > 0,
                           let newPrice = newSellingPrice, newPrice > 0 {
                            let margin = ((newPrice - cost) / newPrice) * 100
                            HStack {
                                Text("Nuevo Margen")
                                Spacer()
                                Text(String(format: "%.1f%%", margin))
                                    .foregroundStyle(margin >= 20 ? .green : (margin >= 10 ? .orange : .red))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                } header: {
                    Text("Precio de Venta (Opcional)")
                } footer: {
                    if updateSellingPrice {
                        Text("El precio se actualizará en Square POS.")
                    }
                }

                // Supplier
                Section {
                    Button {
                        showSupplierPicker = true
                    } label: {
                        HStack {
                            if isLoadingSuppliers {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Cargando proveedores...")
                                    .foregroundStyle(.secondary)
                            } else if let supplier = selectedSupplier {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(supplier.name)
                                            .foregroundStyle(.primary)
                                        // Show preferred badge if this supplier is the preferred one
                                        if let ps = productSuppliers.first(where: { $0.id == supplier.id }), ps.isPreferred {
                                            Text("Preferido")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundStyle(.blue)
                                                .clipShape(.rect(cornerRadius: 4))
                                        }
                                    }
                                    // Show last cost from this supplier
                                    if let lastCost = supplierLastCost {
                                        HStack(spacing: 4) {
                                            Text("Último costo: $\(String(format: "%.2f", lastCost))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            // Show comparison with current unit cost entry
                                            if let currentCost = unitCost, currentCost > 0 {
                                                let diff = currentCost - lastCost
                                                let pct = lastCost > 0 ? (diff / lastCost) * 100 : 0
                                                if abs(diff) > 0.01 {
                                                    Text(diff > 0 ? "\u{2191}\(String(format: "+%.1f%%", pct))" : "\u{2193}\(String(format: "%.1f%%", pct))")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(diff > 0 ? .red : .green)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text("Seleccionar Proveedor")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedSupplier != nil {
                                Button {
                                    selectedSupplier = nil
                                    supplierLastCost = nil
                                    supplierCostNote = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Quitar proveedor")
                            }
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Show supplier cost note (e.g. "Auto-filled from preferred supplier")
                    if let note = supplierCostNote {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text(note)
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Proveedor (Opcional)")
                } footer: {
                    if !productSuppliers.isEmpty && selectedSupplier == nil {
                        Text("\(productSuppliers.count) supplier(s) available for this product")
                    }
                }

                // Invoice & Batch
                Section("Números de Referencia (Opcional)") {
                    TextField("Número de Factura", text: $invoiceNumber)
                    TextField("Número de Lote", text: $batchNumber)
                }

                // Expiry Date
                Section {
                    Toggle("Tiene Fecha de Vencimiento", isOn: $hasExpiry)

                    if hasExpiry {
                        DatePicker("Fecha de Vencimiento", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                // Notes
                Section("Notas (Opcional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Recibir Inventario")
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
                        Task { await saveReceiving() }
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
            .sheet(isPresented: $showSupplierPicker) {
                SupplierPickerView(
                    suppliers: viewModel.suppliers,
                    selectedSupplier: $selectedSupplier
                )
            }
            .onAppear {
                // Pre-select product if provided (from ProductDetailView context)
                if let product = preSelectedProduct, selectedProduct == nil {
                    selectedProduct = product
                    // Fetch suppliers for the pre-selected product
                    Task { await loadProductSuppliers(for: product.id) }
                }
            }
            .onChange(of: selectedProduct) { oldValue, newValue in
                // When product changes, fetch its suppliers to find preferred one
                if let product = newValue, product.id != oldValue?.id {
                    // Reset supplier state
                    productSuppliers = []
                    selectedSupplier = nil
                    supplierLastCost = nil
                    supplierCostNote = nil
                    Task { await loadProductSuppliers(for: product.id) }
                }
            }
            .onChange(of: selectedSupplier) { oldValue, newValue in
                // When supplier changes, update last cost display
                if let supplier = newValue {
                    if let ps = productSuppliers.first(where: { $0.id == supplier.id }) {
                        supplierLastCost = ps.costDouble
                        // Auto-fill unit cost if empty
                        if unitCost == nil && ps.costDouble > 0 {
                            unitCost = ps.costDouble
                            supplierCostNote = "Costo auto-completado del último precio del proveedor"
                        } else {
                            supplierCostNote = nil
                        }
                    } else {
                        supplierLastCost = nil
                        supplierCostNote = nil
                    }
                } else {
                    supplierLastCost = nil
                    supplierCostNote = nil
                }
            }
        }
    }

    // MARK: - Load Product Suppliers

    private func loadProductSuppliers(for productId: String) async {
        isLoadingSuppliers = true
        defer { isLoadingSuppliers = false }

        do {
            let response: ProductSuppliersResponse = try await APIClient.shared.request(
                endpoint: .productSuppliers(productId: productId)
            )
            productSuppliers = response.suppliers

            // Auto-select preferred supplier if user hasn't picked one yet
            if selectedSupplier == nil,
               let preferred = response.suppliers.first(where: { $0.isPreferred }) {
                // Find matching Supplier from the viewModel's supplier list
                if let matchingSupplier = viewModel.suppliers.first(where: { $0.id == preferred.id }) {
                    selectedSupplier = matchingSupplier
                    supplierLastCost = preferred.costDouble
                    if unitCost == nil && preferred.costDouble > 0 {
                        unitCost = preferred.costDouble
                        supplierCostNote = "Costo auto-completado del proveedor preferido"
                    }
                }
            }
        } catch {
            // Supplier loading is optional, don't block the form
            print("Failed to load product suppliers: \(error)")
        }
    }

    private func saveReceiving() async {
        guard let product = selectedProduct,
              let qty = quantity,
              let cost = unitCost,
              let locationId = authManager.currentLocation?.id else { return }

        let priceToUpdate: Double? = updateSellingPrice ? newSellingPrice : nil

        let success = await viewModel.receiveInventory(
            productId: product.id,
            quantity: qty,
            unitCost: cost,
            locationId: locationId,
            supplierId: selectedSupplier?.id,
            invoiceNumber: invoiceNumber,
            batchNumber: batchNumber,
            expiryDate: hasExpiry ? expiryDate : nil,
            notes: notes,
            sellingPrice: priceToUpdate,
            syncPriceToSquare: true
        )

        if success {
            onComplete?()
            dismiss()
        }
    }
}
