import SwiftUI
import FarmaciaKit

// MARK: - Receive Inventory Form View
//
// Layout (tasks/inventory-forms-redesign-epic.md), in the order the paperwork
// is read: what's arriving and how many (the hero) → who sent it, the invoice
// and the cost (the same piece of paper; supplier first, since it fills the
// cost) → sale price → lot and expiry → notes. Lot and expiry move up, right
// after the quantity, for products that expire (`ExpiryPlacement`, from the
// latest receiving; tasks/lot-expiry-capture-epic.md). One action at the bottom,
// always enabled; what's missing shows on the field after a tap.
// The supplier is chosen by a push, so the form presents nothing.

struct ReceiveInventoryFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel

    /// The product being received (from its detail screen, or the scanner's Recibir).
    let product: Product
    /// Called after a successful receive with the quantity, so the parent can refresh data
    var onComplete: ((Int) -> Void)?
    /// Set by the scanner: closing goes back to it instead of dismissing its whole sheet.
    var onClose: (() -> Void)? = nil
    /// A reminder shown under the product (the scanner's "Ya recibiste…").
    var note: String? = nil
    /// The scanner's run supplier (Recibir › "Recibiendo de"): picked over the preferred one.
    var runSupplier: RunSupplier = .unset
    /// The cost typed in Nuevo producto just before (scanner, Recibir): the server
    /// drops it without initial stock, so it would be asked for twice.
    var prefillCost: Double? = nil

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    @State private var quantity: Int?
    @State private var receivingCost = ReceivingCost()
    @State private var updateSellingPrice = false
    @State private var newSellingPrice: Double?
    @State private var marginPick = MarginPick()
    @State private var invoiceNumber = ""
    @State private var batchNumber = ""
    /// Empty means no expiry. Saved as the 1st of the month.
    @State private var expiryMonth: MonthYear?
    /// Up top until the latest receiving says the product doesn't expire.
    @State private var expiryPlacement = ExpiryPlacement.prominent
    @State private var showLotScanner = false
    @State private var selectedSupplier: Supplier?
    @State private var notes = ""
    /// "Count it first": shown when the store's open Conteo inicial hasn't counted this product.
    @State private var countWarning: String?
    /// One per receiving being entered: a retry (or the offline queue's replay) reuses it.
    @State private var clientRequestId = UUID().uuidString

    /// Failed taps on the button: errors show from the first one, and each one
    /// shakes the fields still missing.
    @State private var attempts = 0
    /// Saved: the button shows a checkmark for a moment before the sheet closes.
    @State private var isDone = false

    /// The form as it opened, kept in step with what it fills in itself (the
    /// preferred supplier and its last cost): the baseline for unsaved changes.
    @State private var start: ReceivingDraft?
    @State private var showDiscardConfirmation = false

    private var draft: ReceivingDraft {
        var draft = ReceivingDraft(expiryDate: expiryMonth?.firstDay() ?? .distantPast)
        draft.quantity = quantity
        draft.boxes = receivesByBox ? boxes : nil
        draft.perBox = receivesByBox ? perBox : nil
        draft.unitCost = receivingCost.value
        draft.updatesPrice = updateSellingPrice
        draft.newPrice = newSellingPrice
        draft.supplierId = selectedSupplier?.id
        draft.invoiceNumber = invoiceNumber
        draft.batchNumber = batchNumber
        draft.hasExpiry = expiryMonth != nil
        draft.notes = notes
        return draft
    }

    /// Anything the user entered: the sheet can't be swiped away and Cancelar
    /// asks before discarding it.
    private var hasUnsavedChanges: Bool {
        start.map { draft.hasChanges(from: $0) } ?? false
    }

    private enum Field: Hashable {
        case quantity, boxes, perBox, invoiceNumber, unitCost, sellingPrice, batchNumber, notes
    }
    @State private var receivesByBox = false
    @State private var boxes: Int?
    @State private var perBox: Int?
    @FocusState private var focusedField: Field?

    /// Top to bottom, skipping rows that aren't shown.
    private var focusOrder: FocusOrder<Field> {
        let lotUpTop = expiryPlacement == .prominent
        return FocusOrder((receivesByBox ? [.boxes, .perBox] : [.quantity])
            + (lotUpTop ? [.batchNumber] : [])
            + [.invoiceNumber, .unitCost]
            + (updateSellingPrice ? [.sellingPrice] : [])
            + (lotUpTop ? [] : [.batchNumber])
            + [.notes])
    }

    // Supplier intelligence
    @State private var productSuppliers: [ProductSupplier] = []
    /// Every store's stock, to split the delivery; empty (hidden) if the fetch fails.
    @State private var storeStock: [StoreStock] = []
    /// True from the start: the load begins as the form opens, and a tap before
    /// the task runs must wait too.
    @State private var isLoadingSuppliers = true
    /// The full supplier list (normally loaded by the product page): the preferred
    /// supplier can't be picked without it, so a tap waits for it too.
    @State private var isLoadingSupplierList = true
    /// A tap came in while the supplier's cost was loading: it continues once loaded.
    @State private var waitingForSupplier = false
    /// The product's suppliers didn't load: say so, or the empty fields look like a bug.
    @State private var suppliersFailed = false
    @State private var supplierLastCost: Double?
    /// The cost was filled in from the supplier's last one.
    @State private var costFromSupplier = false

    private func fillQuantityFromBoxes() {
        guard receivesByBox else { return }
        quantity = PackQuantity.total(boxes: boxes, perBox: perBox)
    }

    private var issues: [ReceivingForm.Issue] {
        ReceivingForm.issues(
            quantity: quantity,
            unitCost: receivingCost.value,
            updatesPrice: updateSellingPrice,
            newPrice: newSellingPrice
        )
    }

    /// Where a missing quantity is fixed: the hero, or — by the box, with boxes
    /// typed — the units per box.
    private var quantityField: Field {
        guard receivesByBox else { return .quantity }
        return (boxes ?? 0) > 0 ? .perBox : .boxes
    }

    private func field(for issue: ReceivingForm.Issue) -> Field {
        switch issue {
        case .quantity: quantityField
        case .cost: .unitCost
        case .price: .sellingPrice
        }
    }

    /// The message under `field`, once the user has tried to save.
    private func error(_ field: Field) -> String? {
        guard attempts > 0, let issue = issues.first(where: { self.field(for: $0) == field }) else { return nil }
        // By the box, with boxes typed, what's missing is the box size.
        return field == .perBox ? "Indica cuántas unidades trae cada caja" : issue.message
    }

    /// This store's stock: from the fresh fetch when it's in, else the cached product's.
    private var currentStock: Int? {
        StoreStock.here(storeStock, currentLocationId: authManager.currentLocation?.id) ?? product.totalInventory
    }

    private var costChange: CostChange? {
        supplierLastCost.flatMap { CostChange(current: receivingCost.value, last: $0) }
    }

    /// The margin the product had at the old cost: the "Actual" chip.
    private var currentMargin: Double? {
        guard let price = product.sellingPrice,
              let oldCost = ReceivingPrice.oldCost(supplierLast: supplierLastCost, average: product.averageCost),
              let margin = Margin.percent(price: price, cost: oldCost),
              margin > 0
        else { return nil }
        return margin
    }

    private var marginOptions: [MarginChips.Option] {
        let cost = receivingCost.value
        var options: [MarginChips.Option] = []
        if let currentMargin {
            options.append(.init(
                label: "Actual",
                margin: currentMargin,
                price: ReceivingPrice.keepingMargin(
                    currentPrice: product.sellingPrice,
                    oldCost: ReceivingPrice.oldCost(supplierLast: supplierLastCost, average: product.averageCost),
                    newCost: cost
                )
            ))
        }
        options += PriceSuggestion.chips.map { margin in
            .init(label: "\(Int(margin))%", margin: margin,
                  price: cost.flatMap { PriceSuggestion.price(cost: $0, marginPercent: margin) })
        }
        return options
    }

    /// Above the button: what's missing after a failed tap, else the total.
    private var summary: (text: String, tone: Tone)? {
        if attempts > 0, let missing = ReceivingForm.summary(issues) {
            return (missing, .critical)
        }
        guard let qty = quantity, qty > 0, let cost = receivingCost.value else { return nil }
        return ("\(qty) uds × \(cost.mxn) · Total \((Double(qty) * cost).mxn)", .neutral)
    }

    /// Nothing when there's no open count or a read fails: it's a hint, never a guess.
    private func readCountWarning() async -> String? {
        guard let locationId = authManager.currentLocation?.id,
              let active: APIResponse<StockCountSession> = try? await APIClient.shared.request(
                  endpoint: .stockCountActive, queryParams: ["locationId": locationId]),
              let session = active.data,
              let entry: APIResponse<CountedEntry> = try? await APIClient.shared.request(
                  endpoint: .stockCountProductEntry(id: session.id),
                  queryParams: ["productId": product.id, "locationId": locationId])
        else { return nil }
        return ReceiveCountWarning.text(countOpen: true, counted: entry.data != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ProductSummaryRow(product: product, stock: currentStock)
                } footer: {
                    if let note {
                        Label(note, systemImage: "info.circle")
                    }
                    if let countWarning {
                        Label(countWarning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                quantitySection
                if expiryPlacement == .prominent { lotSection }
                supplierSection
                priceSection
                if expiryPlacement == .optional { lotSection }

                Section {
                    TextField("Notas", text: $notes, prompt: Text("Algo que deba saber el equipo"), axis: .vertical)
                        .lineLimit(2...5)
                        .formField(.notes, focus: $focusedField)
                } header: {
                    OptionalHeader(title: "Notas")
                }
            }
            // No edits while a save is in flight.
            .disabled(viewModel.isSubmitting || isDone || waitingForSupplier)
            .storeStrip()
            .primaryActionBar(PrimaryActionBar(
                // Names the store at the moment of saving (brief §D).
                title: authManager.currentLocation.map { "Recibir en \($0.name)" } ?? "Recibir inventario",
                doneTitle: "Inventario recibido",
                summary: summary?.text,
                summaryTone: summary?.tone ?? .neutral,
                isSubmitting: viewModel.isSubmitting || waitingForSupplier,
                isDone: isDone,
                action: submit
            ))
            .sensoryFeedback(.error, trigger: attempts)
            .navigationTitle("Recibir inventario")
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
                            close()
                        }
                    }
                    .disabled(viewModel.isSubmitting || isDone)
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
                if let cost = prefillCost {
                    // Not added to the baseline: it was typed (in Nuevo producto), so Cancelar asks first.
                    receivingCost.prefill(cost, forProductId: product.id)
                }
                await loadProductSuppliers(for: product.id)
            }
            .task { await loadSupplierList() }
            .task(id: authManager.currentLocation?.id) { countWarning = await readCountWarning() }
            // At the form's level, not on the Lote section: presented from a
            // Form cell it closed right away and took the receiving sheet with it.
            .fullScreenCover(isPresented: $showLotScanner) {
                LotScannerView { scan in
                    if let lot = scan.lot { batchNumber = lot }
                    if let expiry = scan.expiry { expiryMonth = expiry }
                }
            }
            .task {
                expiryPlacement = await loadExpiryPlacement()
            }
            .task {
                guard StoreStock.isExpected(tracksInventory: product.tracksInventory,
                                            soldOnlyAtLocationId: product.soldOnlyAtLocationId) else { return }
                storeStock = await APIClient.shared.storeStock(productId: product.id)
            }
            // The full supplier list can arrive after the product's suppliers
            .onChange(of: viewModel.suppliers.map(\.id)) {
                applyPreferredSupplier()
            }
            .onChange(of: selectedSupplier) { _, supplier in
                supplierChanged(to: supplier)
            }
            .onChange(of: isLoadingSuppliers || isLoadingSupplierList) { _, loading in
                guard !loading, waitingForSupplier else { return }
                waitingForSupplier = false
                // In a Task: the preferred supplier is picked in the same update,
                // and its cost fills in its own onChange; the tap runs after both.
                Task { submit() }
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
            Button("Descartar", role: .destructive) { close() }
            Button("Seguir editando", role: .cancel) {}
        } message: {
            Text("Se perderá la información que ingresaste.")
        }
    }

    // MARK: - Sections

    private var quantitySection: some View {
        Section {
            Picker("Recibir por", selection: $receivesByBox.animation()) {
                Text("Unidades").tag(false)
                Text("Cajas").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            QuantityStepper(
                value: receivesByBox ? $boxes : $quantity,
                unit: receivesByBox ? "cajas" : "unidades",
                focus: $focusedField,
                field: receivesByBox ? .boxes : .quantity
            )
            .fieldError(error(receivesByBox ? .boxes : .quantity), shake: attempts, field: receivesByBox ? Field.boxes : .quantity)

            if receivesByBox {
                AmountField("Unidades por caja", unit: "UDS", value: $perBox, focus: $focusedField, field: .perBox)
                    .fieldError(error(.perBox), shake: attempts, field: Field.perBox)

                // The arithmetic, so nobody multiplies in their head.
                if let boxes, let perBox, let total = PackQuantity.total(boxes: boxes, perBox: perBox) {
                    LabeledContent("Total", value: "\(boxes) × \(perBox) = \(total) uds")
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Cantidad recibida")
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // What saving does to this store's stock.
                if let impact = StockImpact(before: currentStock, change: quantity) {
                    StatusLabel(
                        [authManager.currentLocation?.name, impact.summary]
                            .compactMap { $0 }.joined(separator: " · "),
                        tone: impact.tone,
                        systemImage: "arrow.up.circle.fill"
                    )
                    .monospacedDigit()
                }
                if let summary = StoreStock.summary(storeStock, currentLocationId: authManager.currentLocation?.id) {
                    Label(summary, systemImage: "building.2")
                        .accessibilityLabel("Existencia por tienda: \(summary)")
                }
            }
        }
        // Typing boxes fills the quantity. Switching to Cajas keeps a typed
        // quantity until the boxes add up to one; back to Unidades keeps the
        // total, ready to edit.
        .onChange(of: boxes) { fillQuantityFromBoxes() }
        .onChange(of: perBox) { fillQuantityFromBoxes() }
        .onChange(of: receivesByBox) {
            if let total = PackQuantity.total(boxes: boxes, perBox: perBox), receivesByBox {
                quantity = total
            }
        }
    }

    private var supplierSection: some View {
        Section {
            NavigationLink {
                SupplierPickerView(
                    suppliers: $viewModel.suppliers,
                    selectedSupplier: $selectedSupplier
                )
            } label: {
                LabeledContent {
                    if isLoadingSuppliers {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Cargando proveedores")
                    } else {
                        Text(selectedSupplier?.name ?? "Sin proveedor")
                    }
                } label: {
                    HStack(spacing: DS.Spacing.s) {
                        Text("Proveedor")
                        if isPreferred {
                            Text("Preferido")
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.xs)
                                .padding(.vertical, DS.Spacing.xxs)
                                .background(Tone.info.color.opacity(0.15), in: .rect(cornerRadius: DS.Radius.s))
                                .foregroundStyle(Tone.info.color)
                        }
                    }
                }
            }

            LabeledContent("Factura") {
                TextField("Factura", text: $invoiceNumber, prompt: Text("Número"))
                    .multilineTextAlignment(.trailing)
                    .formField(.invoiceNumber, focus: $focusedField)
            }
            // Row-level id: .formKeyboard scrolls to it (see .fieldError).
            .id(Field.invoiceNumber)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                AmountField(
                    "Costo unitario",
                    prefix: "$",
                    unit: "MXN",
                    value: $receivingCost.value,
                    focus: $focusedField,
                    field: .unitCost,
                    prompt: ReceivingCost.hint(previous: ReceivingPrice.oldCost(supplierLast: supplierLastCost,
                                                                                average: product.averageCost))
                )
                // Catches supplier increases and typos; the arrow says it without color.
                if let costChange {
                    Text(costChange.text)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(costChange.tone.color)
                }
            }
            .fieldError(error(.unitCost), shake: attempts, field: Field.unitCost)
        } header: {
            Text("Proveedor y costo")
        } footer: {
            if suppliersFailed && selectedSupplier == nil {
                Text("No se pudieron cargar los proveedores; elige uno o escribe el costo.")
            } else if costFromSupplier, let supplier = selectedSupplier {
                Text("Costo tomado del último precio de \(supplier.name).")
            } else if !productSuppliers.isEmpty && selectedSupplier == nil {
                Text(productSuppliers.count == 1
                    ? "1 proveedor disponible para este producto."
                    : "\(productSuppliers.count) proveedores disponibles para este producto.")
            }
        }
        .onChange(of: receivingCost.value) { _, cost in
            // A picked margin follows the cost.
            if updateSellingPrice, let price = marginPick.price(forCost: cost) {
                newSellingPrice = price
            }
        }
    }

    /// The new price's margin and profit at this cost, for the chips' header.
    private var newMarginResult: (margin: Double, profit: Double)? {
        guard let cost = receivingCost.value, let price = newSellingPrice,
              let margin = Margin.percent(price: price, cost: cost) else { return nil }
        return (margin, price - cost)
    }

    private var isPreferred: Bool {
        guard let id = selectedSupplier?.id else { return false }
        return productSuppliers.first { $0.id == id }?.isPreferred == true
    }

    @ViewBuilder
    private var priceSection: some View {
        if let currentPrice = product.sellingPrice {
            Section {
                LabeledContent {
                    Text(currentPrice.mxn)
                        .strikethrough(updateSellingPrice && newSellingPrice != nil)
                        .monospacedDigit()
                } label: {
                    Text(updateSellingPrice ? "Precio actual" : "Precio")
                    if let cost = receivingCost.value, let margin = Margin.percent(price: currentPrice, cost: cost) {
                        Text("Margen \(Int(margin.rounded()))% con este costo")
                            .foregroundStyle(Margin.tone(forPercent: margin).color)
                    }
                }

                Toggle("Cambiar precio", isOn: $updateSellingPrice.animation())

                if updateSellingPrice {
                    MarginChips(
                        options: marginOptions,
                        selected: marginPick.selected,
                        onSelect: { margin in
                            marginPick.selected = margin
                            newSellingPrice = marginPick.price(forCost: receivingCost.value)
                        },
                        onOther: {
                            marginPick.selected = nil
                            focusedField = .sellingPrice
                        },
                        result: newMarginResult,
                        onRelease: { marginPick.selected = nil }
                    )

                    LabeledContent {
                        AmountField(prefix: "$", unit: "MXN", value: $newSellingPrice, focus: $focusedField,
                                    field: .sellingPrice, alignment: .trailing)
                    } label: {
                        Text("Nuevo precio")
                    }
                    .fieldError(error(.sellingPrice), shake: attempts, field: Field.sellingPrice)
                }
            } header: {
                Text("Precio de venta")
            } footer: {
                if updateSellingPrice {
                    Text("Con un margen elegido, el precio sigue al costo; escribe un precio para fijarlo. "
                         + PriceEditing.scopeNote(allLocations: priceAtAllLocations, syncToSquare: true,
                                                  inSquare: product.hasSquareSync == true,
                                                  storeName: authManager.currentLocation?.name ?? "esta sucursal",
                                                  isOwner: authManager.isOwner))
                } else if costChange?.isUp == true {
                    Text("El costo subió: revisa el precio.")
                }
            }
            .onChange(of: updateSellingPrice) { _, on in
                // Keeping the margin is the usual reaction to a cost increase: one tap.
                guard on, newSellingPrice == nil, let currentMargin else { return }
                marginPick.selected = currentMargin
                newSellingPrice = marginPick.price(forCost: receivingCost.value)
            }
            .onChange(of: newSellingPrice) { _, price in
                marginPick.priceTyped(price, cost: receivingCost.value)
            }
        }
    }

    // MARK: - Actions

    private func submit() {
        guard !viewModel.isSubmitting, !isDone, !waitingForSupplier else { return }
        switch ReceivingSubmit.action(isLoadingProductSuppliers: isLoadingSuppliers,
                                      isLoadingSupplierList: isLoadingSupplierList,
                                      unitCost: receivingCost.value, issues: issues) {
        case .wait:
            focusedField = nil
            waitingForSupplier = true
        case .showIssues(let first):
            attempts += 1
            // Focus scrolls the field into view (.formKeyboard) and opens its keyboard.
            focusedField = field(for: first)
            if let missing = ReceivingForm.summary(issues) {
                AccessibilityNotification.Announcement(missing).post()
            }
        case .save:
            focusedField = nil
            // Set before the Task runs, so a second tap can't slip in first
            viewModel.isSubmitting = true
            Task { await saveReceiving() }
        }
    }

    /// A new price goes to every store for the owner, no question asked
    /// (tasks/price-all-locations-epic.md); Editar Precio sets one store's.
    private var priceAtAllLocations: Bool {
        PriceEditing.appliesToAllLocations(isOwner: authManager.isOwner,
                                           soldOnlyAtLocationId: product.soldOnlyAtLocationId)
    }

    private func supplierChanged(to supplier: Supplier?) {
        guard let supplier,
              let ps = productSuppliers.first(where: { $0.id == supplier.id }) else {
            supplierLastCost = nil
            costFromSupplier = false
            return
        }
        supplierLastCost = ps.costDouble
        // Auto-fill unit cost if empty
        if receivingCost.offerSupplierCost(ps.costDouble, forProductId: product.id) {
            // Filled in by the form, not the user: not an unsaved change.
            start?.unitCost = receivingCost.value
            costFromSupplier = true
        } else {
            costFromSupplier = false
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
        } catch is CancellationError {
            // The form closed: nothing to show.
        } catch {
            suppliersFailed = true
            // Supplier loading is optional, don't block the form
            print("Failed to load product suppliers: \(error)")
        }
    }

    /// Loads the full supplier list only if the product page hasn't (it usually has).
    private func loadSupplierList() async {
        defer { isLoadingSupplierList = false }
        if viewModel.suppliers.isEmpty { await viewModel.loadSuppliers() }
        // Picked here, in the same update that ends the wait, like the product's suppliers.
        // Also with the list already in: the run supplier doesn't wait for the product's.
        applyPreferredSupplier()
    }

    /// Selects the run's or the product's preferred supplier once both lists are in. Runs when
    /// either loads; onChange(of: selectedSupplier) then fills its last cost.
    private func applyPreferredSupplier() {
        let preferredId = productSuppliers.first(where: { $0.isPreferred })?.id
        guard let id = PreferredSupplier.pick(
            run: runSupplier,
            preferredId: preferredId,
            selectedId: selectedSupplier?.id,
            available: viewModel.suppliers.map(\.id)
        ) else { return }
        selectedSupplier = viewModel.suppliers.first { $0.id == id }
        // Picked by the form, not the user: not an unsaved change.
        start?.supplierId = selectedSupplier?.id
    }

    /// Expiry first when it's up top: on a medication box it's what matters.
    private var lotSection: some View {
        Section {
            if expiryPlacement == .prominent { expiryRow }
            LabeledContent("Lote") {
                HStack(spacing: DS.Spacing.s) {
                    TextField("Lote", text: $batchNumber, prompt: Text("Número"))
                        .multilineTextAlignment(.trailing)
                        .formField(.batchNumber, focus: $focusedField)
                    if LotScannerView.isSupported {
                        Button("Escanear lote y caducidad", systemImage: "camera.viewfinder") {
                            showLotScanner = true
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
            }
            // Row-level id: .formKeyboard scrolls to it (see .fieldError).
            .id(Field.batchNumber)
            if expiryPlacement == .optional { expiryRow }
        } header: {
            Text("Lote y caducidad")
        } footer: {
            if expiryPlacement == .prominent && expiryMonth == nil {
                Text("Vacío si no tiene caducidad.")
            }
        }
    }

    private var expiryRow: some View {
        MonthYearPicker(title: "Vence", value: $expiryMonth.animation())
    }

    /// From the product's latest receiving; up top if it can't be loaded.
    private func loadExpiryPlacement() async -> ExpiryPlacement {
        let response: ReceivingExpiriesResponse? = try? await APIClient.shared.request(
            endpoint: .listReceivingsByProduct(productId: product.id)
        )
        return ExpiryPlacement(expiriesNewestFirst: response?.data.map(\.expiryDate) ?? [])
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
            expiryDate: expiryMonth?.firstDay(),
            notes: notes,
            sellingPrice: updateSellingPrice ? newSellingPrice : nil,
            priceAtAllLocations: updateSellingPrice && priceAtAllLocations,
            clientRequestId: clientRequestId
        ))

        if success {
            isDone = true
            onComplete?(qty)
            // Long enough to read the checkmark, short enough not to wait on.
            try? await Task.sleep(for: .milliseconds(600))
            close()
        }
    }
}

/// GET /inventory/receive/product/:id, newest first: only whether each had an expiry.
private struct ReceivingExpiriesResponse: Decodable {
    struct Row: Decodable { let expiryDate: Date? }
    let data: [Row]
}
