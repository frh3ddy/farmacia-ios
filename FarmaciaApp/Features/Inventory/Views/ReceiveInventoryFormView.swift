import SwiftUI
import FarmaciaKit

// MARK: - Receive Inventory Form View
//
// Design-system pilot (tasks/design-system-epic.md): AmountField, Margin/Tone,
// .formKeyboard; the supplier is chosen by a push, so the form presents nothing.

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
    @State private var notes = ""
    /// One per receiving being entered: a retry (or the offline queue's replay) reuses it.
    @State private var clientRequestId = UUID().uuidString

    private enum Field: Hashable {
        case quantity, unitCost, sellingPrice, invoiceNumber, batchNumber
    }
    @FocusState private var focusedField: Field?

    private var focusOrder: FocusOrder<Field> {
        FocusOrder([.quantity, .unitCost]
            + (updateSellingPrice ? [.sellingPrice] : [])
            + [.invoiceNumber, .batchNumber])
    }

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
                    AmountField(
                        "Cantidad",
                        unit: "UDS",
                        quantity: $quantity,
                        focus: $focusedField,
                        field: .quantity
                    )

                    AmountField(
                        "Costo Unitario",
                        unit: "MXN",
                        value: $receivingCost.value,
                        focus: $focusedField,
                        field: .unitCost
                    )

                    if let qty = quantity, qty > 0,
                       let cost = receivingCost.value, cost > 0 {
                        HStack {
                            Text("Costo Total")
                            Spacer()
                            Text("$\(String(format: "%.2f", Double(qty) * cost))")
                                .bold()
                        }
                    }
                }

                // Selling Price Update (Optional)
                Section {
                    Toggle("Actualizar Precio de Venta", isOn: $updateSellingPrice)

                    if updateSellingPrice {
                        AmountField(
                            "Nuevo Precio",
                            unit: "MXN",
                            value: $newSellingPrice,
                            focus: $focusedField,
                            field: .sellingPrice
                        )

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
                           let newPrice = newSellingPrice,
                           let margin = Margin.percent(price: newPrice, cost: cost) {
                            HStack {
                                Text("Nuevo Margen")
                                Spacer()
                                Text(String(format: "%.1f%%", margin))
                                    .foregroundStyle(Margin.tone(forPercent: margin).color)
                                    .bold()
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
                    NavigationLink {
                        SupplierPickerView(
                            suppliers: $viewModel.suppliers,
                            selectedSupplier: $selectedSupplier
                        )
                    } label: {
                        HStack {
                            if isLoadingSuppliers {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Cargando proveedores...")
                                    .foregroundStyle(.secondary)
                            } else if let supplier = selectedSupplier {
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    HStack(spacing: DS.Spacing.s) {
                                        Text(supplier.name)
                                            .foregroundStyle(.primary)
                                        // Show preferred badge if this supplier is the preferred one
                                        if let ps = productSuppliers.first(where: { $0.id == supplier.id }), ps.isPreferred {
                                            Text("Preferido")
                                                .font(.caption)
                                                .padding(.horizontal, DS.Spacing.xs)
                                                .padding(.vertical, DS.Spacing.xxs)
                                                .background(Tone.info.color.opacity(0.15), in: .rect(cornerRadius: DS.Radius.s))
                                                .foregroundStyle(Tone.info.color)
                                        }
                                    }
                                    // Show last cost from this supplier
                                    if let lastCost = supplierLastCost {
                                        HStack(spacing: DS.Spacing.xs) {
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
                                                        .foregroundStyle((diff > 0 ? Tone.critical : .positive).color)
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
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Quitar proveedor")
                            }
                        }
                    }

                    // Show supplier cost note (e.g. "Auto-filled from preferred supplier")
                    if let note = supplierCostNote {
                        Label(note, systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Tone.info.color)
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
                        .formField(.invoiceNumber, focus: $focusedField)
                    TextField("Número de Lote", text: $batchNumber)
                        .formField(.batchNumber, focus: $focusedField)
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
            .formKeyboard(focus: $focusedField, order: focusOrder)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        // Set before the Task runs, so a second tap can't slip in first
                        guard !viewModel.isSubmitting else { return }
                        viewModel.isSubmitting = true
                        Task { await saveReceiving() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
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
            // The full supplier list can arrive after the product's suppliers
            .onChange(of: viewModel.suppliers.map(\.id)) {
                applyPreferredSupplier()
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
            applyPreferredSupplier()
        } catch {
            // Supplier loading is optional, don't block the form
            print("Failed to load product suppliers: \(error)")
        }
    }

    /// Selects the product's preferred supplier once both lists are in. Runs when
    /// either loads; onChange(of: selectedSupplier) then fills its last cost.
    private func applyPreferredSupplier() {
        let preferredId = productSuppliers.first(where: { $0.isPreferred })?.id
        guard let id = PreferredSupplier.pick(
            preferredId: preferredId,
            selectedId: selectedSupplier?.id,
            available: viewModel.suppliers.map(\.id)
        ) else { return }
        selectedSupplier = viewModel.suppliers.first { $0.id == id }
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
