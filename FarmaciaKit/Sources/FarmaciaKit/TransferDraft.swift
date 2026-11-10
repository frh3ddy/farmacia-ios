import Foundation

// MARK: - Transfer draft (Más → Transferencias)
//
// The products being sent to another store in one POST /transfers/batch. The batch
// refuses a repeated productId, so a second scan raises the line instead of adding one.

public struct TransferDraft: Equatable, Sendable {
    public struct Line: Equatable, Identifiable, Sendable {
        public let productId: String
        public let name: String
        /// On hand at this (the sending) store.
        public let available: Int
        public var quantity: Int
        public let imageUrl: String?
        public var id: String { productId }

        public init(productId: String, name: String, available: Int, quantity: Int, imageUrl: String? = nil) {
            self.productId = productId
            self.name = name
            self.available = available
            self.quantity = quantity
            self.imageUrl = imageUrl
        }
    }

    public private(set) var lines: [Line] = []
    /// Same for every retry of this draft, so a resend after a timeout can't ship twice.
    public private(set) var clientRequestId: String

    public init(clientRequestId: String = UUID().uuidString) {
        self.clientRequestId = clientRequestId
    }

    /// Unknown stock (`nil`) counts as none, so it can't be sent until it's known.
    public mutating func add(productId: String, name: String, available: Int?, imageUrl: String? = nil) {
        let available = available ?? 0
        if let index = lines.firstIndex(where: { $0.productId == productId }) {
            lines[index].quantity += 1
        } else {
            lines.append(Line(productId: productId, name: name, available: available, quantity: 1, imageUrl: imageUrl))
        }
    }

    public mutating func remove(productId: String) {
        lines.removeAll { $0.productId == productId }
    }

    public mutating func setQuantity(_ quantity: Int, for productId: String) {
        guard let index = lines.firstIndex(where: { $0.productId == productId }) else { return }
        lines[index].quantity = quantity
    }

    // MARK: Checks (every line is checked before sending: the batch reports only its first failure)

    public static let maxItems = 100

    public static func lineIssue(quantity: Int, available: Int) -> String? {
        if available <= 0 { return "Sin existencias en esta tienda" }
        if quantity <= 0 { return "La cantidad debe ser mayor que cero" }
        if quantity > available { return "Solo hay \(available) en esta tienda" }
        return nil
    }

    public var capIssue: String? {
        lines.count > Self.maxItems ? "Máximo \(Self.maxItems) productos por envío" : nil
    }

    /// What to fix before Enviar can send, or nil when it can.
    public func sendIssue(destinationId: String?) -> String? {
        if destinationId == nil { return "Elige la sucursal destino" }
        if lines.isEmpty { return "Agrega al menos un producto" }
        if let capIssue { return capIssue }
        if lines.contains(where: { Self.lineIssue(quantity: $0.quantity, available: $0.available) != nil }) {
            return "Revisa las cantidades marcadas"
        }
        return nil
    }

    public func canSend(destinationId: String?) -> Bool {
        sendIssue(destinationId: destinationId) == nil
    }

    // MARK: Destination

    /// Every open store but this one (`inactive`: stores GET /locations marks closed).
    public static func destinations(all: [String], inactive: Set<String> = [], current: String?) -> [String] {
        all.filter { $0 != current && !inactive.contains($0) }
    }

    /// Today's two-store case needs no picking.
    public static func defaultDestination(all: [String], inactive: Set<String> = [], current: String?) -> String? {
        let others = destinations(all: all, inactive: inactive, current: current)
        return others.count == 1 ? others[0] : nil
    }

    // MARK: Text

    public var summary: String {
        Self.summary(products: lines.count, pieces: lines.reduce(0) { $0 + $1.quantity })
    }

    /// "3 productos · 24 unidades" (a box product's unit is the box): a draft's, or a shipment's as the server returned it.
    public static func summary(products: Int, pieces: Int) -> String {
        (products == 1 ? "1 producto" : "\(products) productos") + " · " + (pieces == 1 ? "1 unidad" : "\(pieces) unidades")
    }

    /// The line under each product in the picker.
    public static func pickerSubtitle(sku: String?, available: Int?) -> String {
        guard let available, available > 0 else { return "Sin existencias aquí" }
        let stock = "hay \(available) aquí"
        guard let sku, !sku.isEmpty else { return stock.prefix(1).uppercased() + stock.dropFirst() }
        return "SKU \(sku) · \(stock)"
    }

    /// After a send, from the shipment the server returned (not the draft: a replayed
    /// request returns the first shipment, as it is now).
    public static func sentText(destination: String, inTransit: Bool, products: Int, pieces: Int) -> String {
        let what = summary(products: products, pieces: pieces)
        return inTransit
            ? "En camino a \(destination): \(what). \(destination) lo confirmará al recibir."
            : "Enviado a \(destination): \(what). Ya están en su inventario."
    }

    /// A shipment's row in Recientes, seen from this store.
    public static func direction(from origin: String, to destination: String, outgoing: Bool) -> String {
        outgoing ? "Para \(destination)" : "De \(origin)"
    }

    // MARK: Sending

    public func request(destinationId: String, receiveOnSend: Bool) -> TransferBatchRequest {
        TransferBatchRequest(
            toLocationId: destinationId,
            clientRequestId: clientRequestId,
            receiveOnSend: receiveOnSend,
            items: lines.map { .init(productId: $0.productId, quantity: $0.quantity) }
        )
    }

    /// CLIENT_REQUEST_ID_REUSED (or a store switch): the same list, as a new shipment.
    public mutating func renewRequestId(_ clientRequestId: String = UUID().uuidString) {
        self.clientRequestId = clientRequestId
    }

    /// After a successful send: a new list is a new shipment.
    public mutating func reset(clientRequestId: String = UUID().uuidString) {
        lines = []
        self.clientRequestId = clientRequestId
    }

    /// The API lets the OWNER, or a manager at both stores, receive on send; anyone else
    /// sends "Confirmar al llegar", so the other store counts it.
    /// Whether this send lands at once: only when "Confirmar al llegar" is off and allowed off.
    public static func receivesOnSend(confirmOnArrival: Bool, allowed: Bool) -> Bool {
        !confirmOnArrival && allowed
    }

    public static func receiveOnSendAllowed(isOwner: Bool, accessibleStoreIds: Set<String>, destinationId: String) -> Bool {
        isOwner || accessibleStoreIds.contains(destinationId)
    }
}
