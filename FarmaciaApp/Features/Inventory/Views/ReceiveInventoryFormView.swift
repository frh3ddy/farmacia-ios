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

    /// The form as it opened, kept in step with what it fills in itself (the
    /// preferred supplier and its last cost): the baseline for unsaved changes.
    @State private var start: ReceivingDraft?
    @State private var showDiscardConfirmation = false

    private var draft: ReceivingDraft {
        var draft = ReceivingDraft(expiryDate: expiryDate)
        draft.quantity = quantity
        draft.unitCost = receivingCost.value
        draft.updatesPrice = updateSellingPrice
        draft.newPrice = newSellingPrice
        draft.supplierId = selectedSupplier?.id
        draft.invoiceNumber = invoiceNumber
        draft.batchNumber = batchNumber
        draft.hasExpiry = hasExpiry
        draft.notes = notes
        return draft
    }

    /// Anything the user entered: the sheet can't be swiped away and Cancelar
    /// asks before discarding it.
    private var hasUnsavedChanges: Bool {
        start.map { draft.hasChanges(from: $0) } ?? false
    }

    private enum Field: Hashable {
        case quantity, unitCost, sellingPrice, invoiceNumber, batchNumber, notes
    }
    @FocusState private var focusedField: Field?

    /// Más detalles: price update, invoice, batch, notes.
    @State private var showsDetails = false

    /// Top to bottom, skipping rows that aren't shown.
    private var focusOrder: FocusOrder<Field> {
        guard showsDetails else { return FocusOrder([.quantity, .unitCost]) }
        return FocusOrder([.quantity, .unitCost]
            + (updateSellingPrice ? [.sellingPrice] : [])
            + [.invoiceNumber, .batchNumber, .notes])
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
            // Layout (tasks/form-ux-polish-epic.md): what's being received on top,
            // then the receiving itself, supplier, expiry (kept visible: it
            // matters for a pharmacy), and everything optional under Más detalles.
            Form {
                Section {
                    ProductSummaryRow(product: product)
                }

                Section {
                    AmountField(
                        "Cantidad",
                        unit: "UDS",
                        value: $quantity,
                        focus: $focusedField,
                        field: .quantity
                    )

                    AmountField(
                        "Costo unitario",
                        unit: "MXN",
                        value: $receivingCost.value,
                        focus: $focusedField,
                        field: .unitCost
                    )

                    if let qty = quantity, qty > 0,
                       let cost = receivingCost.value, cost > 0 {
                        LabeledContent("Costo total") {
                            Text("$\(String(format: "%.2f", Double(qty) * cost))")
                                .bold()
                        }
                    }
                }

                supplierSection

                Section {
                    Toggle("Tiene fecha de vencimiento", isOn: $hasExpiry)

                    if hasExpiry {
                        DatePicker("Vence", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showsDetails) {
                        Toggle("Actualizar precio de venta", isOn: $updateSellingPrice)

                        if updateSellingPrice {
                            AmountField(
                                "Nuevo precio",
                                unit: "MXN",
                                value: $newSellingPrice,
                                focus: $focusedField,
                                field: .sellingPrice
                            )

                            if let currentPrice = product.sellingPrice {
                                LabeledContent("Precio actual", value: "$\(String(format: "%.2f", currentPrice)) MXN")
                            }

                            if let cost = receivingCost.value, cost > 0,
                               let newPrice = newSellingPrice,
                               let margin = Margin.percent(price: newPrice, cost: cost) {
                                LabeledContent("Nuevo margen") {
                                    Text(String(format: "%.1f%%", margin))
                                        .foregroundStyle(Margin.tone(forPercent: margin).color)
                                        .bold()
                                }
                            }
                        }

                        LabeledContent("Factura") {
                            TextField("Factura", text: $invoiceNumber, prompt: Text("Número"))
                                .multilineTextAlignment(.trailing)
                                .formField(.invoiceNumber, focus: $focusedField)
                        }

                        LabeledContent("Lote") {
                            TextField("Lote", text: $batchNumber, prompt: Text("Número"))
                                .multilineTextAlignment(.trailing)
                                .formField(.batchNumber, focus: $focusedField)
                        }

                        TextField("Notas", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                            .formField(.notes, focus: $focusedField)
                    } label: {
                        MoreDetailsLabel(hasHiddenDetails: !showsDetails && draft.hasDetails)
                    }
                } footer: {
                    if showsDetails && updateSellingPrice {
                        Text("El precio también se actualiza en Square POS.")
                    }
                }
            }
            // No edits while a save is in flight.
            .disabled(viewModel.isSubmitting)
            .navigationTitle("Recibir Inventario")
            .navigationBarTitleDisplayMode(.inline)
            .formKeyboard(focus: $focusedField, order: focusOrder)
            // Swiping the sheet down would lose what's been entered, or
            // interrupt a save in flight.
            .interactiveDismissDisabled(hasUnsavedChanges || viewModel.isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if hasUnsavedChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    // While saving, the button becomes a spinner in its place
                    // (the Mail/Settings pattern) and turns back on failure.
                    if viewModel.isSubmitting {
                        ProgressView()
                            .accessibilityLabel("Guardando")
                    } else {
                        Button("Guardar") {
                            // Set before the Task runs, so a second tap can't slip in first
                            guard !viewModel.isSubmitting else { return }
                            viewModel.isSubmitting = true
                            Task { await saveReceiving() }
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
            .task {
                if start == nil { start = draft }
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
                            // Filled in by the form, not the user: not an unsaved change.
                            start?.unitCost = receivingCost.value
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
        // On the NavigationStack, not the Cancelar button: attached to the button,
        // iOS 26 shrinks the dialog back into it before the sheet may start
        // closing — a half-second stall after Descartar (measured on device).
        // Not on the Form either: it already hosts other presentations.
        .confirmationDialog(
            "¿Descartar recepción?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Descartar", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("Se perderá la información que ingresaste.")
        }
    }

    // MARK: - Sections

    private var supplierSection: some View {
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
                            .controlSize(.small)
                        Text("Cargando proveedores...")
                            .foregroundStyle(.secondary)
                    } else if let supplier = selectedSupplier {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            HStack(spacing: DS.Spacing.s) {
                                Text(supplier.name)
                                    .foregroundStyle(.primary)
                                if let ps = productSuppliers.first(where: { $0.id == supplier.id }), ps.isPreferred {
                                    Text("Preferido")
                                        .font(.caption)
                                        .padding(.horizontal, DS.Spacing.xs)
                                        .padding(.vertical, DS.Spacing.xxs)
                                        .background(Tone.info.color.opacity(0.15), in: .rect(cornerRadius: DS.Radius.s))
                                        .foregroundStyle(Tone.info.color)
                                }
                            }
                            if let lastCost = supplierLastCost {
                                HStack(spacing: DS.Spacing.xs) {
                                    Text("Último costo: $\(String(format: "%.2f", lastCost))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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
                        LabeledContent("Proveedor", value: "Ninguno")
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

            if let note = supplierCostNote {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Tone.info.color)
            }
        } header: {
            Text("Proveedor")
        } footer: {
            if !productSuppliers.isEmpty && selectedSupplier == nil {
                Text(productSuppliers.count == 1
                    ? "1 proveedor disponible para este producto."
                    : "\(productSuppliers.count) proveedores disponibles para este producto.")
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
        // Picked by the form, not the user: not an unsaved change.
        start?.supplierId = selectedSupplier?.id
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
