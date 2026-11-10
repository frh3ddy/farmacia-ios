import Foundation

// MARK: - Transfer requests and text
//
// POST /transfers/batch sends many products in one shipment (all or nothing).
// POST /transfers/shipments/:id/receive takes in a shipment sent with "Confirmar al llegar".

public struct TransferBatchRequest: Encodable, Equatable, Sendable {
    public struct Item: Encodable, Equatable, Sendable {
        public let productId: String
        public let quantity: Int
    }

    public let toLocationId: String
    public let clientRequestId: String
    public let receiveOnSend: Bool
    public let items: [Item]
}

public enum TransferStatus: String, Sendable {
    case pending = "PENDING"
    case inTransit = "IN_TRANSIT"
    case received = "RECEIVED"
    case cancelled = "CANCELLED"

    public var title: String {
        switch self {
        case .pending: "Pendiente"
        case .inTransit: "En tránsito"
        case .received: "Recibida"
        case .cancelled: "Cancelada"
        }
    }

    /// The title for a status as sent; one this app doesn't know shows as is, so a new
    /// server value doesn't fail a whole list (models decode `status` as a String).
    public static func title(raw: String) -> String {
        TransferStatus(rawValue: raw)?.title ?? raw
    }
}

/// A batch stops at its first failing item and returns one `{ code, message, productId }`.
public enum TransferError {
    public static func message(code: String?, productName: String?, available: Int?,
                               destination: String, fallback: String) -> String {
        let name = productName ?? "Un producto"
        switch code {
        case "INSUFFICIENT_STOCK":
            guard let available else { return "\(name): no hay suficientes en esta tienda" }
            return "\(name): solo hay \(available) en esta tienda"
        case "PRODUCT_NOT_SOLD_AT_LOCATION": return "\(name) no se vende en \(destination)"
        case "LOCATION_NOT_CUT_OVER": return "Esta tienda aún no ha hecho su conteo inicial"
        case "DESTINATION_NOT_CUT_OVER": return "\(destination) aún no ha hecho su conteo inicial"
        case "CLIENT_REQUEST_ID_REUSED": return "No se pudo enviar. Toca Enviar de nuevo."
        case "RECEIVE_ON_SEND_NOT_ALLOWED": return "No tienes acceso a \(destination): envía con «Confirmar al llegar»"
        default: return fallback
        }
    }
}

extension TransferError {
    /// A send that failed before any answer: it may have committed. A retry as is
    /// can't duplicate it (same clientRequestId), but an edited list wouldn't be sent.
    public static func mayHaveSent(_ error: NetworkError) -> Bool {
        switch error {
        case .timeout, .networkUnavailable, .unknown: true
        default: false
        }
    }

    /// The id was used by another store's send: a client bug, so the list gets a new id.
    public static func needsNewRequestId(code: String) -> Bool {
        code == "CLIENT_REQUEST_ID_REUSED"
    }

    public static let mayHaveSentText =
        "Puede que ya se haya enviado. Revisa Recientes antes de cambiar la lista; reenviarla tal cual no la duplica."

    /// The send worked; only Square's copy of the stock is behind (owner-only retry, on the web).
    public static func squareFailed(product: String) -> String {
        "\(product): Square no se actualizó. El dueño puede reintentarlo en la web."
    }
}

/// The "Por recibir" form: one received quantity per product. The API takes one per
/// lot (FIFO line), so a shortfall comes off the last lot first, then the one before.
public struct ShipmentReceipt: Equatable, Sendable {
    public struct LotLine: Equatable, Sendable {
        public let id: String
        public let quantity: Int
        public init(id: String, quantity: Int) { self.id = id; self.quantity = quantity }
    }

    public struct Transfer: Equatable, Sendable {
        public let id: String
        public let lines: [LotLine]
        public init(id: String, lines: [LotLine]) { self.id = id; self.lines = lines }
    }

    public struct Line: Encodable, Equatable, Sendable {
        public let transferLineId: String
        public let quantityReceived: Int
    }

    public struct Request: Encodable, Equatable, Sendable {
        /// Omitted when nothing was edited: every line arrives as sent.
        public let lines: [Line]?
    }

    public let transfers: [Transfer]
    /// Received per transfer (product); a missing entry arrives as sent.
    public var received: [String: Int] = [:]

    public init(transfers: [Transfer]) { self.transfers = transfers }

    public func sent(for transferId: String) -> Int {
        transfers.first { $0.id == transferId }?.lines.reduce(0) { $0 + $1.quantity } ?? 0
    }

    public var request: Request {
        var overrides: [Line] = []
        for transfer in transfers {
            guard let got = received[transfer.id] else { continue }
            var short = sent(for: transfer.id) - got
            guard short > 0 else { continue }
            for lot in transfer.lines.reversed() where short > 0 {
                let taken = min(short, lot.quantity)
                short -= taken
                overrides.append(Line(transferLineId: lot.id, quantityReceived: lot.quantity - taken))
            }
        }
        overrides.sort { $0.transferLineId < $1.transferLineId }
        return Request(lines: overrides.isEmpty ? nil : overrides)
    }

    public func note(for transferId: String) -> String? {
        guard let got = received[transferId] else { return nil }
        let sentQty = sent(for: transferId)
        if got < 0 { return "La cantidad no puede ser negativa" }
        if got > sentQty { return "No puede ser más de \(sentQty)" }
        return got < sentQty ? "Faltan \(sentQty - got)" : nil
    }

    public var canReceive: Bool {
        received.allSatisfy { id, got in got >= 0 && got <= sent(for: id) }
    }
}

/// Transferencias' lists from GET /transfers/shipments (shipments either side of this store).
public enum ShipmentList {
    public static let recentLimit = 10

    /// Por recibir: in transit to this store. Everything else goes in Recientes.
    public static func isToReceive(inTransit: Bool, toLocationId: String, current: String?) -> Bool {
        inTransit && toLocationId == current
    }

    public static func recent<T>(_ shipments: [T]) -> [T] {
        Array(shipments.prefix(recentLimit))
    }
}
