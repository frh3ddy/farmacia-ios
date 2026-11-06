import SwiftUI
import FarmaciaKit

// MARK: - Adjustment Form View
//
// On the form kit (tasks/design-system-epic.md): product summary, AmountField,
// .formKeyboard, Guardar → spinner while saving.

struct AdjustmentFormView: View {
    let adjustmentType: AdjustmentType
    @ObservedObject var viewModel: InventoryViewModel

    /// The product being adjusted (from its detail screen, or the scanner's Contar).
    let product: Product
    /// Called after a successful adjustment so the parent can refresh data
    var onComplete: (() -> Void)?
    /// A count saved, or matched the stock: (live stock it was compared to, counted).
    var onCounted: ((Int?, Int) -> Void)? = nil
    /// Set by the scanner: closing goes back to it instead of dismissing its whole sheet.
    var onClose: (() -> Void)? = nil
    /// A reminder shown under the product (the scanner's "Ya contaste…").
    var note: String? = nil

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    /// A count that agrees with the stock: Guardar becomes "Sin cambios" and just closes,
    /// except in a Conteo inicial, where saving it marks the product counted.
    private var countMatches: Bool {
        adjustmentType.isVariable && CountCorrection.matches(counted: newCount, current: liveStock)
    }

    /// The store's open Conteo inicial. While there is one, a count goes to it
    /// instead of Corrección de Conteo, so it stays out of shrinkage.
    @State private var session: StockCountSession?
    /// Lots in a Conteo inicial, pre-filled with the product's current ones. Shown only once that read
    /// succeeds, so lots are never typed against an API that would drop them.
    @State private var lotSplit = LotSplit()
    private var lots: [CountLot] { lotSplit.rows }
    @State private var originalLots: [CountLot] = []
    @State private var lotsLoad = CountLotsLoad()
    /// The lots section shows, and its lots are sent, only for the store and count they were read for.
    private var lotsAvailable: Bool {
        guard let locationId = authManager.currentLocation?.id else { return false }
        return lotsLoad.isAvailable(locationId: locationId, session: session)
    }
    /// Bumped to reload through `.task(id:)`, which cancels a load still running.
    @State private var reloadID = 0
    /// This product's count earlier in the open Conteo inicial (counts span days).
    @State private var countedEntry: CountedEntry?
    /// The lot row a camera scan of the box fills (receiving's `LotScannerView`).
    @State private var scanningLotId: UUID?
    @State private var showLotScanner = false
    private var countLots: CountLots { CountLots(lots, original: originalLots) }
    private var lotsCheck: LotsCheck { countLots.check(counted: newCount) }
    /// Only a Conteo inicial sends Razón/Notas to the endpoint that caps them.
    private var notesProblem: String? {
        session != nil ? CountNotes.problem(reason: reason, notes: notes) : nil
    }
    private var lotsBlock: Bool {
        if case .mismatch = lotsCheck { return true }
        return false
    }

    private var countSave: CountSave {
        CountSave.action(matches: countMatches, inOpeningCount: session != nil)
    }

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var quantity: Int?
    @State private var newCount: Int?
    @State private var unitCost: Double?
    /// Set when the API refused for lack of a cost on record; reveals the cost field.
    @State private var costRequired = false
    @State private var reason = ""
    @State private var notes = ""
    private enum Field: Hashable { case quantity, newCount, unitCost, reason, notes, lotQuantity(UUID) }
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
            return network.isConnected
                && CountSave.canSave(change: countChange, matches: countMatches, inOpeningCount: session != nil)
                && !lotsBlock
                && notesProblem == nil
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
                } footer: {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        if let note {
                            Label(note, systemImage: "info.circle")
                        }
                        if let countedEntry {
                            Label(countedEntry.note(), systemImage: "checkmark.circle")
                            if let remarks = countedEntry.remarks {
                                Text(remarks)
                            }
                        }
                    }
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
                                    reloadID += 1
                                }
                            } else {
                                ProgressView()
                            }
                        }

                        if adjustmentType == .countCorrection {
                            // The receiving form's hero stepper: counting is mostly ± from the shelf.
                            // Only the counter's changes split the count over the lots; the stock loading
                            // and "Sin cambios" set `newCount` directly, so pre-filled lots stay as they are.
                            QuantityStepper(value: Binding { newCount } set: {
                                lotSplit.countChanged(from: newCount, to: $0)
                                newCount = $0
                            }, unit: "unidades", focus: $focusedField, field: .newCount)
                            if let stock = CountSave.quickMatch(liveStock: liveStock, inOpeningCount: session != nil) {
                                Button {
                                    saveUnchanged(stock)
                                } label: {
                                    Label("Sin cambios: hay \(stock)", systemImage: "checkmark.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isSubmitting || !network.isConnected
                                          || countLots.quickMatchBlocker(stock: stock) != nil || notesProblem != nil)
                            }
                        } else {
                            AmountField(
                                "Nueva cantidad",
                                unit: "UDS",
                                value: $newCount,
                                focus: $focusedField,
                                field: .newCount
                            )
                        }
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
                    if session != nil {
                        Label("Conteo inicial: corrige existencias de la migración, no cuenta como merma.", systemImage: "checklist")
                    }
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

                if lotsAvailable {
                    lotsSection
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
                    // Row-level id: .formKeyboard scrolls to it (see .fieldError).
                    .id(Field.reason)
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(1...4)
                        .formField(.notes, focus: $focusedField)
                } footer: {
                    if let notesProblem {
                        StatusLabel(notesProblem, tone: .caution)
                    }
                }
            }
            // No edits while a save is in flight.
            .disabled(viewModel.isSubmitting)
            .navigationTitle(session != nil ? AdjustmentType.openingCount.displayName : adjustmentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .formKeyboard(focus: $focusedField, order: focusOrder)
            .interactiveDismissDisabled(viewModel.isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        close()
                    }
                    .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    // While saving, the button becomes a spinner in its place.
                    if viewModel.isSubmitting {
                        ProgressView()
                            .accessibilityLabel("Guardando")
                    } else if countSave == .closeWithoutSaving, let newCount {
                        Button("Sin cambios") {
                            onCounted?(liveStock, newCount)
                            close()
                        }
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
            // At the form's level, not on the lots section: presented from a Form cell it closed
            // right away and took the sheet with it (see ReceiveInventoryFormView).
            .fullScreenCover(isPresented: $showLotScanner) {
                LotScannerView { scan in
                    guard let id = scanningLotId, let index = lots.firstIndex(where: { $0.id == id }) else { return }
                    lotSplit.rows[index] = lots[index].applying(scan)
                }
            }
            .alert("No se pudo guardar", isPresented: $viewModel.showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.saveError ?? "")
            }
            // Reloads when the location changes or the connection comes back
            .task(id: [authManager.currentLocation?.id, String(network.isConnected), String(reloadID)]) {
                await loadLiveStock()
            }
        }
    }

    private func loadLiveStock() async {
        liveStock = nil
        session = nil
        liveStockFailed = false
        guard network.isConnected,
              let locationId = authManager.currentLocation?.id else { return }

        do {
            // A count can't be saved without knowing whether a Conteo inicial is open:
            // guessing "no" would book migration fixes as shrinkage.
            var open: StockCountSession?
            if adjustmentType == .countCorrection {
                do {
                    let active: APIResponse<StockCountSession> = try await APIClient.shared.request(
                        endpoint: .stockCountActive,
                        queryParams: ["locationId": locationId]
                    )
                    open = active.data
                } catch let error where StockCountSession.noCountOnServer(error) {
                    open = nil
                }
                guard !Task.isCancelled else { return }
            }
            // Once the count is known the rest is read at the same time: in a store-wide
            // count this runs for every product scanned.
            let count = open // a let: the concurrent reads can't capture a var
            async let entry = readCountedEntry(in: count, locationId: locationId)
            async let lots = readLots(in: count, locationId: locationId)
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .getProduct(id: product.id),
                queryParams: ["locationId": locationId]
            )
            let (counted, rows) = await (entry, lots)
            // A superseded load (location or connection changed) must not
            // overwrite the newer one's state — URLSession may finish or fail anyway.
            guard !Task.isCancelled else { return }
            session = open
            liveStock = response.data.totalInventory ?? 0
            countedEntry = counted
            if let rows {
                lotSplit = LotSplit(prefilled: rows, stock: response.data.totalInventory ?? 0)
                originalLots = rows
                lotsLoad.loaded(locationId: locationId, session: open)
            }
            // A count starts at the stock, so it's ± from what's on record.
            if adjustmentType == .countCorrection {
                newCount = CountSave.startValue(liveStock: liveStock, typed: newCount)
            }
        } catch {
            guard !Task.isCancelled else { return }
            liveStockFailed = true
        }
    }

    /// This product's count earlier in the open Conteo inicial. Nothing shows if the read fails (an API without it).
    private func readCountedEntry(in session: StockCountSession?, locationId: String) async -> CountedEntry? {
        guard let session else { return nil }
        let entry: APIResponse<CountedEntry>? = try? await APIClient.shared.request(
            endpoint: .stockCountProductEntry(id: session.id),
            queryParams: ["productId": product.id, "locationId": locationId]
        )
        return entry?.data
    }

    /// The product's lots, once per store and count (`CountLotsLoad`); nil when already read or the read fails.
    private func readLots(in session: StockCountSession?, locationId: String) async -> [CountLot]? {
        guard lotsLoad.needsLoad(locationId: locationId, session: session) else { return nil }
        let current: APIResponse<[CurrentLot]>? = try? await APIClient.shared.request(
            endpoint: .inventoryLots,
            queryParams: ["productId": product.id, "locationId": locationId]
        )
        return current?.data?.map(\.row)
    }

    /// Caducidad is what matters; the lote is optional. Lots may cover less than the count (the rest
    /// stays without lot info), never more.
    private var lotsSection: some View {
        Section {
            ForEach($lotSplit.rows) { $lot in
                VStack(spacing: DS.Spacing.s) {
                    MonthYearPicker(title: "Vence", value: $lot.expiry)
                    let quantity = Binding<Int?> { lot.quantity } set: { lotSplit.setQuantity($0, of: lot.id) }
                    HStack {
                        AmountField("Cantidad", unit: "UDS", value: quantity,
                                    focus: $focusedField, field: .lotQuantity(lot.id))
                        Stepper("Cantidad", value: Binding { quantity.wrappedValue ?? 0 } set: { quantity.wrappedValue = $0 },
                                in: 0...Int.max)
                            .labelsHidden()
                    }
                    LabeledContent("Lote") {
                        HStack(spacing: DS.Spacing.s) {
                            TextField("Lote", text: $lot.batchNumber, prompt: Text("Opcional"))
                                .multilineTextAlignment(.trailing)
                            if LotScannerView.isSupported {
                                Button("Escanear lote y caducidad", systemImage: "camera.viewfinder") {
                                    scanLot(into: lot.id)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    if let hint = lot.ignoredHint {
                        StatusLabel(hint, tone: .caution)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .onDelete { lotSplit.remove(atOffsets: $0, count: newCount) }
            Button("Agregar lote", systemImage: "plus") { lotSplit.add(CountLot(), count: newCount) }
                .disabled(!CountLots.canAdd(to: lots))
            if LotScannerView.isSupported {
                // The fast path on the shelf: a new row filled from the box.
                Button("Escanear caja", systemImage: "camera.viewfinder") {
                    let row = CountLot()
                    lotSplit.add(row, count: newCount)
                    scanLot(into: row.id)
                }
                .disabled(!CountLots.canAdd(to: lots))
            }
        } header: {
            Text("Lotes y caducidad")
        } footer: {
            switch lotsCheck {
            case .mismatch(let reason):
                StatusLabel(reason, tone: .caution)
            case .partial(let rest):
                Text(rest)
            case .none, .matches:
                if lots.isEmpty { Text("Opcional. Basta con la caducidad; el lote puede quedar vacío.") }
            }
        }
    }

    private func scanLot(into id: UUID) {
        focusedField = nil
        scanningLotId = id
        showLotScanner = true
    }

    /// Conteo inicial's one tap: the shelf matches the stock, so save it as the count.
    private func saveUnchanged(_ stock: Int) {
        guard !viewModel.isSubmitting else { return }
        newCount = stock
        focusedField = nil
        viewModel.isSubmitting = true
        Task { await saveAdjustment() }
    }

    private func saveAdjustment() async {
        if let session, adjustmentType == .countCorrection, let newCount {
            let outcome = await viewModel.recordOpeningCount(
                sessionId: session.id,
                productId: product.id,
                countedQuantity: newCount,
                unitCost: asksForCost ? unitCost : nil,
                clientRequestId: clientRequestId,
                lots: lotsAvailable ? countLots.requestLots() : nil,
                locationId: authManager.currentLocation?.id,
                reason: reason,
                notes: notes
            )
            finish(outcome)
            // The owner may have ended the count since the form opened: reload, so the
            // next Guardar goes to whatever is open now (the title follows).
            if case .failed = outcome { reloadID += 1 }
            return
        }

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

        finish(outcome)
        // The API refuses a correction while a Conteo inicial is open (one may have started
        // since the form loaded): reload, so the next Guardar goes to the count.
        if case .failed = outcome, adjustmentType == .countCorrection { reloadID += 1 }
    }

    private func finish(_ outcome: SaveOutcome) {
        switch outcome {
        case .saved:
            onComplete?()
            if adjustmentType == .countCorrection, let newCount { onCounted?(liveStock, newCount) }
            close()
        case .costRequired:
            costRequired = true
        case .failed:
            break
        }
    }
}
