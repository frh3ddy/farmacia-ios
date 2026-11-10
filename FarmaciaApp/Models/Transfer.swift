import Foundation
import FarmaciaKit

// MARK: - Transfers (shipments)
//
// POST /transfers/batch, GET /transfers/shipments and POST /transfers/shipments/:id/receive
// all answer with this Shipment. Statuses stay Strings (`TransferStatus.title(raw:)`), so
// a value this app doesn't know doesn't fail the whole list.

struct Shipment: Decodable, Identifiable, Equatable {
    struct Store: Decodable, Equatable {
        let id: String
        let name: String
    }

    let id: String
    let fromLocationId: String
    let toLocationId: String
    /// Received on send: nobody counted it on arrival.
    let receiveOnSend: Bool
    let shippedAt: Date?
    let status: String
    let fromLocation: Store
    let toLocation: Store
    let transfers: [ShipmentTransfer]

    var isInTransit: Bool { status == TransferStatus.inTransit.rawValue }
}

struct ShipmentTransfer: Decodable, Identifiable, Equatable {
    struct ProductRef: Decodable, Equatable {
        let id: String
        let name: String
        let sku: String?
        let squareImageUrl: String?
    }

    struct Line: Decodable, Equatable {
        let id: String
        let quantity: Int
        let quantityReceived: Int?
    }

    let id: String
    let productId: String
    let quantity: Int
    let status: String
    let squareSynced: Bool
    let squareSyncError: String?
    let product: ProductRef
    let lines: [Line]

    var isInTransit: Bool { status == TransferStatus.inTransit.rawValue }
}

struct ShipmentResponse: Decodable {
    let data: Shipment
}

struct ShipmentListResponse: Decodable {
    let data: [Shipment]
}
