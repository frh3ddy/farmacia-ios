import SwiftUI
import FarmaciaKit

// MARK: - Receive Inventory Form View

struct ReceiveInventoryFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel

    /// The product being received (the form opens from its detail screen).
    let product: Product
    /// Called after a successful receive so the parent can refresh data
    var onComplete: (() -> Void)?

    @State private var quantity: Int?
    @State private var receivingCost = ReceivingCost()
    @State private var updateSellingPrice = false
    @State private var newSellingPrice: Double?
    @State private var invoiceNumber = ""
    @State private var batchNumber = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year
    @State private var selectedSupplier: Supplier?
    @State private var showSupplierPicker = false
    @State private var notes = ""
    /// One per receiving being entered: a retry (or the offline queue's replay) reuses it.
    @State private var clientRequestId = UUID().uuidString

    private enum Field: Hashable {
        case quantity, unitCost, sellingPrice
    }
    @FocusState private var focusedField: Field?

    // Supplier intelligence
    @State private var productSuppliers: [ProductSupplier] = []
    @State private var isLoadingSuppliers = false
    @State private var supplierLastCost: Double?
    @State private var supplierCostNote: String?

    private var isValid: Bool {
        ReceivingForm.canSave(
            quantity: quantity,
            unitCost: receivingCost.value,
            updatesPrice: updateSellingPrice,
            newPrice: newSellingPrice
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // Product Selection
                Section("Producto") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(product.displayName)
                                .foregroundStyle(.primary)
                            if let sku = product.sku {
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
                }

                // Quantity & Cost
                Section("Cantidad y Costo") {
                    HStack {
                        Text("Cantidad")
                        TextField("0", value: $quantity, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .quantity)
                        Text("UDS")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .quantity }

                    HStack {
                        Text("Costo Unitario")
                        TextField("0.00", value: $receivingCost.value, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .unitCost)
                        Text("MXN")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { focusedField = .unitCost }

                    if let qty = quantity, qty > 0,
                       let cost = receivingCost.value, cost > 0 {
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
                            TextField("0.00", value: $newSellingPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .sellingPrice)
                            Text("MXN")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { focusedField = .sellingPrice }

                        // Show current price if available
                        if let currentPrice = product.sellingPrice {
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
                        if let cost = receivingCost.value, cost > 0,
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
                                            if let currentCost = receivingCost.value, currentCost > 0 {
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
            .keyboardTopSpacing(200, isActive: focusedField != nil)
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
                        Task { await saveReceiving() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .sheet(isPresented: $showSupplierPicker) {
                SupplierPickerView(
                    suppliers: $viewModel.suppliers,
                    selectedSupplier: $selectedSupplier
                )
            }
            .alert("No se pudo guardar", isPresented: $viewModel.showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.saveError ?? "")
            }
            .task {
                // Fetch the product's suppliers to auto-pick the preferred one
                receivingCost.productChanged(to: product.id)
                await loadProductSuppliers(for: product.id)
            }
            .onChange(of: selectedSupplier) { oldValue, newValue in
                // When supplier changes, update last cost display
                if let supplier = newValue {
                    if let ps = productSuppliers.first(where: { $0.id == supplier.id }) {
                        supplierLastCost = ps.costDouble
                        // Auto-fill unit cost if empty
                        if receivingCost.offerSupplierCost(ps.costDouble, forProductId: product.id) {
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
                    if receivingCost.offerSupplierCost(preferred.costDouble, forProductId: productId) {
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
        guard let qty = quantity,
              let cost = receivingCost.value,
              let locationId = authManager.currentLocation?.id else {
            viewModel.isSubmitting = false
            return
        }

        let success = await viewModel.receiveInventory(ReceiveInventoryRequest(
            locationId: locationId,
            productId: product.id,
            quantity: qty,
            unitCost: cost,
            supplierId: selectedSupplier?.id,
            invoiceNumber: invoiceNumber,
            batchNumber: batchNumber,
            expiryDate: hasExpiry ? expiryDate : nil,
            notes: notes,
            sellingPrice: updateSellingPrice ? newSellingPrice : nil,
            clientRequestId: clientRequestId
        ))

        if success {
            onComplete?()
            dismiss()
        }
    }
}
