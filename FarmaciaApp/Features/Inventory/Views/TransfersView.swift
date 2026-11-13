import SwiftUI
import FarmaciaKit

// MARK: - Transferencias
//
// Más → Transferencias (OWNER/MANAGER): pick the store to send to, add products by
// name or scan, and send them all in one shipment (POST /transfers/batch, all or
// nothing). By default the other store gets them at once; "Confirmar al llegar"
// leaves them in transit until that store counts them in "Por recibir".
// The list stays on the phone (per employee and store) until it's sent or
// cleared, and its stock is refreshed when it loads.
// tasks/transfers-epic.md, tasks/transfer-list-persist-epic.md

private enum TransferField: Hashable {
    case search
}

struct TransfersView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var draft = TransferDraft()
    /// The picker's pick; it goes into the draft at once, and the picker clears.
    /// Its stock here is `totalInventory` (this store's lots); `quantity` is piezas por caja.
    @State private var picked: Product?
    /// The product sheet: every pick or scan opens it to set how many.
    @State private var sheetProduct: Product?
    @State private var stores: [Location] = []
    @State private var storesFailed = false
    @State private var destinationId: String?
    @State private var confirmOnArrival = false
    @State private var isSending = false
    @State private var confirmSend = false
    @State private var errorMessage: String?
    @State private var sentMessage: String?
    @State private var squareNotes: [String] = []
    /// Shipments to or from this store; nil until the first load.
    @State private var shipments: [Shipment]?
    @State private var shipmentsFailed = false
    @State private var receiving: Shipment?
    @State private var confirmClear = false
    /// The saved list's stock is reloading: Enviar waits.
    @State private var refreshingStock = false
    /// "Cambiaron las existencias: …" after a refresh.
    @State private var stockNotice: String?
    /// The refresh failed: the numbers are from when the products were added.
    @State private var stockStale = false
    /// The saved list couldn't be read: it starts empty, and a note says so.
    @State private var draftLost = false
    /// The key whose saved list is on screen; nil until the first load.
    @State private var loadedKey: String?

    @FocusState private var focusedField: TransferField?

    private var currentId: String? { authManager.currentLocation?.id }

    private var draftKey: String? {
        TransferDraftStore.key(employeeId: authManager.currentEmployee?.id, locationId: currentId)
    }

    private var inactiveStoreIds: Set<String> { Set(stores.filter { $0.isActive == false }.map(\.id)) }

    private var destinations: [Location] {
        let ids = TransferDraft.destinations(all: stores.map(\.id), inactive: inactiveStoreIds, current: currentId)
        return stores.filter { ids.contains($0.id) }
    }

    private var destination: Location? { stores.first { $0.id == destinationId } }

    private var receiveOnSendAllowed: Bool {
        guard let destinationId else { return true }
        return TransferDraft.receiveOnSendAllowed(
            isOwner: authManager.isOwner,
            accessibleStoreIds: Set(authManager.availableLocations.map(\.id)),
            destinationId: destinationId
        )
    }

    private var receiveOnSend: Bool {
        TransferDraft.receivesOnSend(confirmOnArrival: confirmOnArrival, allowed: receiveOnSendAllowed)
    }

    private func isToReceive(_ shipment: Shipment) -> Bool {
        ShipmentList.isToReceive(inTransit: shipment.isInTransit, toLocationId: shipment.toLocationId, current: currentId)
    }

    private var toReceive: [Shipment] { shipments?.filter(isToReceive) ?? [] }

    private var recent: [Shipment] { ShipmentList.recent((shipments ?? []).filter { !isToReceive($0) }) }

    var body: some View {
        Form {
            if let errorMessage {
                Section { StatusLabel(errorMessage, tone: .critical) }
            }
            if let sentMessage {
                Section {
                    StatusLabel(sentMessage, tone: .positive)
                    ForEach(squareNotes, id: \.self) { StatusLabel($0, tone: .caution) }
                }
            }

            destinationSection
            productsSection
            optionsSection
            toReceiveSection
            recentSection
        }
        .primaryActionBar(PrimaryActionBar(
            title: "Enviar",
            doneTitle: "Enviado",
            summary: draft.lines.isEmpty ? nil : draft.summary,
            isSubmitting: isSending,
            isDone: false
        ) { tappedSend() })
        .formKeyboard(focus: $focusedField,
                      order: FocusOrder([.search]))
        .navigationTitle("Transferencias")
        .storeStrip()
        .onChange(of: picked) { _, product in
            guard let product else { return }
            picked = nil
            focusedField = nil
            sheetProduct = product
        }
        .onChange(of: draft) { _, draft in
            guard let draftKey else { return }
            TransferDraftStore.save(draft, to: .standard, key: draftKey)
        }
        // A store switch while this screen is open: the list, its destination and its
        // request id belong to each store; this one's saved list comes back.
        // Logout clears the store (nil) before this screen goes: its list stays saved.
        .onChange(of: currentId) {
            guard currentId != nil else { return }
            destinationId = nil
            shipments = nil
            errorMessage = nil
            sentMessage = nil
            Task {
                await loadStores()
                await loadShipments()
            }
        }
        // On open, and when the store (or employee) changes the key.
        .task(id: draftKey) { await loadDraft() }
        .task { await loadStores() }
        .task { await loadShipments() }
        .refreshable { await loadShipments() }
        .confirmationDialog(confirmTitle, isPresented: $confirmSend, titleVisibility: .visible) {
            Button("Enviar") { Task { await send() } }
        } message: {
            Text([draft.sendWarning,
                  receiveOnSend
                  ? "Las existencias pasan a \(destination?.name ?? "la otra sucursal") al enviar."
                  : "\(destination?.name ?? "La otra sucursal") las confirmará al recibir."]
                .compactMap { $0 }.joined(separator: "\n\n"))
        }
        .sheet(item: $sheetProduct) { product in
            TransferProductSheet(
                product: product,
                start: draft.sheetStart(productId: product.id, available: product.totalInventory),
                actionTitle: draft.sheetAction(productId: product.id)
            ) { quantity in
                draft.set(productId: product.id, name: product.displayName, available: product.totalInventory,
                          quantity: quantity, imageUrl: product.squareImageUrl)
                sentMessage = nil
                errorMessage = nil
            }
        }
        .sheet(item: $receiving) { shipment in
            ShipmentReceiveView(shipment: shipment) { _ in
                receiving = nil
                Task { await loadShipments() }
            }
        }
    }

    private var confirmTitle: String {
        "¿Enviar \(draft.summary) a \(destination?.name ?? "la otra sucursal")?"
    }

    // MARK: Sections

    @ViewBuilder
    private var destinationSection: some View {
        Section("Para") {
            if storesFailed {
                StatusLabel("No se pudieron cargar las sucursales. Revisa la conexión.", tone: .critical)
            } else if destinations.count > 1 {
                Picker("Sucursal", selection: $destinationId) {
                    Text("Elegir").tag(String?.none)
                    ForEach(destinations) { Text($0.name).tag(Optional($0.id)) }
                }
            } else if let only = destinations.first {
                LabeledContent("Sucursal", value: only.name)
            } else if stores.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("No hay otra sucursal a la cual enviar.").foregroundStyle(.secondary)
            }
        }
    }

    private var productsSection: some View {
        Section {
            if let warning = draft.sendWarning {
                StatusLabel(warning, tone: .caution)
            }
            if draftLost {
                StatusLabel("No se pudo recuperar la lista guardada.", tone: .caution)
            }
            if refreshingStock {
                Label {
                    Text("Actualizando existencias…")
                } icon: {
                    ProgressView()
                }
                .foregroundStyle(.secondary)
            } else if let stockNotice {
                StatusLabel(stockNotice, tone: .caution)
            } else if stockStale {
                StatusLabel("No se pudieron actualizar las existencias: son de cuando agregaste los productos.", tone: .caution)
            }
            ProductSearchPicker(selected: $picked, placeholder: "Nombre, SKU o escanea…",
                                field: .search, focus: $focusedField, scanLabel: "Escanear producto",
                                subtitle: { TransferDraft.pickerSubtitle(sku: $0.sku, available: $0.totalInventory) })
            ForEach(draft.lines) { line in
                TransferLineRow(
                    line: line,
                    quantity: Binding(
                        get: { line.quantity },
                        set: { draft.setQuantity($0, for: line.productId) }
                    )
                )
            }
            .onDelete { offsets in
                for index in offsets { draft.remove(productId: draft.lines[index].productId) }
                errorMessage = nil
            }
            if !draft.lines.isEmpty {
                Button("Vaciar lista", role: .destructive) { confirmClear = true }
                    .confirmationDialog("¿Vaciar la lista?", isPresented: $confirmClear, titleVisibility: .visible) {
                        Button("Vaciar", role: .destructive) { clearList() }
                    }
            }
        } header: {
            Text("Productos")
        } footer: {
            if let capIssue = draft.capIssue {
                Text(capIssue).foregroundStyle(.red)
            } else if !draft.lines.isEmpty {
                Text("Desliza un producto a la izquierda para quitarlo.")
            }
        }
    }

    private var optionsSection: some View {
        Section {
            Toggle("Confirmar al llegar", isOn: receiveOnSendAllowed ? $confirmOnArrival : .constant(true))
                .disabled(!receiveOnSendAllowed)
        } footer: {
            if !receiveOnSendAllowed {
                Text("No tienes acceso a \(destination?.name ?? "esa sucursal"): ellos confirmarán al recibir.")
            } else if confirmOnArrival {
                Text("Quedan en tránsito hasta que \(destination?.name ?? "la otra sucursal") las reciba en Por recibir.")
            } else {
                Text("Las existencias pasan a \(destination?.name ?? "la otra sucursal") al enviar.")
            }
        }
    }

    @ViewBuilder
    private var toReceiveSection: some View {
        if !toReceive.isEmpty {
            Section("Por recibir") {
                ForEach(toReceive) { shipment in
                    Button { receiving = shipment } label: {
                        ShipmentRow(shipment: shipment, currentId: currentId)
                    }
                    .tint(.primary)
                }
            }
        }
    }

    private var recentSection: some View {
        Section("Recientes") {
            if shipmentsFailed {
                StatusLabel("No se pudieron cargar las transferencias. Revisa la conexión.", tone: .critical)
            } else if let shipments {
                if shipments.isEmpty {
                    Text("Aún no hay transferencias.").foregroundStyle(.secondary)
                }
                ForEach(recent) { ShipmentRow(shipment: $0, currentId: currentId) }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Actions

    private func tappedSend() {
        sentMessage = nil
        if let issue = draft.sendIssue(destinationId: destinationId, refreshingStock: refreshingStock) {
            errorMessage = issue
            return
        }
        errorMessage = nil
        focusedField = nil
        confirmSend = true
    }

    private func send() async {
        guard let destination else { return }
        // The list being sent: a store switch while waiting swaps in another store's.
        let sentKey = draftKey
        isSending = true
        defer { isSending = false }
        errorMessage = nil
        squareNotes = []
        do {
            let response: ShipmentResponse = try await APIClient.shared.request(
                endpoint: .sendTransfers,
                body: draft.request(destinationId: destination.id, receiveOnSend: receiveOnSend)
            )
            // From what the server returned: a replayed request returns the first shipment.
            let shipment = response.data
            sentMessage = TransferDraft.sentText(
                destination: shipment.toLocation.name,
                inTransit: shipment.isInTransit,
                products: shipment.transfers.count,
                pieces: shipment.transfers.reduce(0) { $0 + $1.quantity }
            )
            squareNotes = shipment.transfers
                .filter { $0.squareSyncError != nil }
                .map { TransferError.squareFailed(product: $0.product.name) }
            updateSentList(sentKey) { $0.reset() }
            if sentKey == draftKey {
                stockNotice = nil
                stockStale = false
            }
            await loadShipments()
        } catch NetworkError.refused(let refusal) {
            if TransferError.needsNewRequestId(code: refusal.code) { updateSentList(sentKey) { $0.renewRequestId() } }
            let name = refusal.productId.flatMap { id in draft.lines.first { $0.productId == id }?.name }
            errorMessage = TransferError.message(code: refusal.code, productName: name, available: refusal.available,
                                                 destination: destination.name, fallback: refusal.message)
        } catch let error as NetworkError where TransferError.mayHaveSent(error) {
            // No answer: it may have gone through. Resending as is can't ship twice
            // (same clientRequestId), so the list stays; Recientes shows whether it went.
            // Changing the list after this warns: it would go as a new shipment.
            updateSentList(sentKey) { $0.markMayHaveSent() }
            errorMessage = TransferError.mayHaveSentText
            await loadShipments()
        } catch {
            guard !NetworkError.isCancellation(error) else { return }
            errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Enviar's outcome goes to the list it sent: the one on screen, or the saved one
    /// when the store switched while it waited.
    private func updateSentList(_ key: String?, _ change: (inout TransferDraft) -> Void) {
        if key == draftKey {
            change(&draft)
        } else if let key {
            TransferDraftStore.update(.standard, key: key, change)
        }
    }

    private func clearList() {
        draft.reset()
        stockNotice = nil
        stockStale = false
        draftLost = false
        errorMessage = nil
    }

    /// This employee's saved list for this store, with its stock refreshed. Once per
    /// key: coming back to the screen keeps the list (and its notes) as they are.
    private func loadDraft() async {
        guard let draftKey, draftKey != loadedKey else { return }
        loadedKey = draftKey
        stockNotice = nil
        stockStale = false
        do {
            draft = try TransferDraftStore.load(.standard, key: draftKey)
            draftLost = false
        } catch {
            draft = TransferDraft()
            draftLost = true
            TransferDraftStore.save(draft, to: .standard, key: draftKey)
        }
        await refreshStock()
    }

    /// One call for the whole list. On failure (or a server without the endpoint)
    /// the saved numbers stay, and a note says they may be old.
    private func refreshStock() async {
        guard let locationId = currentId, let request = draft.stockRequest(locationId: locationId) else { return }
        refreshingStock = true
        defer { refreshingStock = false }
        do {
            let response: APIResponse<[String: Int]> = try await APIClient.shared.request(
                endpoint: .transferStock, body: request)
            // A store switch while waiting: these numbers are the other store's.
            guard currentId == locationId else { return }
            stockNotice = TransferStockChange.notice(draft.refreshAvailable(response.data ?? [:]))
        } catch {
            guard !NetworkError.isCancellation(error), currentId == locationId else { return }
            stockStale = true
        }
    }

    private func loadStores() async {
        do {
            let all: LocationListResponse = try await APIClient.shared.request(endpoint: .listLocations)
            stores = all
            storesFailed = false
            if destinationId == nil {
                destinationId = TransferDraft.defaultDestination(
                    all: all.map(\.id), inactive: Set(all.filter { $0.isActive == false }.map(\.id)), current: currentId)
            }
        } catch {
            guard !NetworkError.isCancellation(error) else { return }
            storesFailed = true
        }
    }

    private func loadShipments() async {
        guard let currentId else { return }
        do {
            let response: ShipmentListResponse = try await APIClient.shared.request(
                endpoint: .listShipments, queryParams: ["locationId": currentId])
            shipments = response.data
            shipmentsFailed = false
        } catch {
            guard !NetworkError.isCancellation(error) else { return }
            shipmentsFailed = true
        }
    }
}

// MARK: - Rows

private struct TransferLineRow: View {
    let line: TransferDraft.Line
    @Binding var quantity: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.m) {
                ProductThumbnail(url: line.imageUrl)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(line.name)
                    Text(line.available > 0 ? "Hay \(line.available) aquí" : "Sin existencias aquí")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(line.quantity)")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .accessibilityHidden(true)
                // −/+ in place: the row keeps its spot. Typing a big number: pick it again (the sheet).
                Stepper("Cantidad de \(line.name)", value: $quantity,
                        in: TransferDraft.stepRange(available: line.available))
                    .labelsHidden()
                    .accessibilityValue("\(line.quantity)")
            }
            if let issue = TransferDraft.lineIssue(quantity: line.quantity, available: line.available) {
                StatusLabel(issue, tone: .critical)
            }
        }
    }
}

private struct ShipmentRow: View {
    let shipment: Shipment
    let currentId: String?

    private var pieces: Int { shipment.transfers.reduce(0) { $0 + $1.quantity } }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                Text(TransferDraft.direction(from: shipment.fromLocation.name, to: shipment.toLocation.name,
                                             outgoing: shipment.fromLocationId == currentId))
                    .font(.headline)
                Spacer()
                Text(TransferStatus.title(raw: shipment.status))
                    .font(.caption)
                    .foregroundStyle(shipment.isInTransit ? .orange : .secondary)
            }
            Text(TransferDraft.summary(products: shipment.transfers.count, pieces: pieces))
                .font(.subheadline)
            if let shippedAt = shipment.shippedAt {
                Text(shippedAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Por recibir

/// Counts what arrived: one quantity per product, prefilled with what was sent.
private struct ShipmentReceiveView: View {
    let shipment: Shipment
    let onReceived: (Shipment) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var receipt: ShipmentReceipt
    @State private var isReceiving = false
    @State private var errorMessage: String?

    init(shipment: Shipment, onReceived: @escaping (Shipment) -> Void) {
        self.shipment = shipment
        self.onReceived = onReceived
        _receipt = State(initialValue: ShipmentReceipt(transfers: shipment.transfers
            .filter(\.isInTransit)
            .map { .init(id: $0.id, lines: $0.lines.map { .init(id: $0.id, quantity: $0.quantity) }) }))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section { StatusLabel(errorMessage, tone: .critical) }
                }
                Section {
                    ForEach(shipment.transfers.filter(\.isInTransit)) { transfer in
                        let sent = receipt.sent(for: transfer.id)
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            HStack(spacing: DS.Spacing.m) {
                                ProductThumbnail(url: transfer.product.squareImageUrl)
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(transfer.product.name)
                                    Text("Enviadas: \(sent)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                TextField("\(sent)", value: Binding(
                                    get: { receipt.received[transfer.id] ?? sent },
                                    set: { receipt.received[transfer.id] = $0 }
                                ), format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 72)
                                    .accessibilityLabel("Recibidas de \(transfer.product.name)")
                            }
                            if let note = receipt.note(for: transfer.id) {
                                StatusLabel(note, tone: receipt.canReceive ? .caution : .critical)
                            }
                        }
                    }
                } header: {
                    Text(TransferDraft.direction(from: shipment.fromLocation.name, to: shipment.toLocation.name, outgoing: false))
                } footer: {
                    Text("Cambia la cantidad solo si llegó menos de lo enviado.")
                }
            }
            .navigationTitle("Recibir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isReceiving {
                        ProgressView()
                    } else {
                        Button("Recibir") { Task { await receive() } }
                            .disabled(!receipt.canReceive)
                    }
                }
            }
        }
    }

    private func receive() async {
        isReceiving = true
        defer { isReceiving = false }
        errorMessage = nil
        do {
            let response: ShipmentResponse = try await APIClient.shared.request(
                endpoint: .receiveShipment(id: shipment.id), body: receipt.request)
            onReceived(response.data)
        } catch {
            guard !NetworkError.isCancellation(error) else { return }
            errorMessage = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        }
    }
}
