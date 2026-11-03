import Foundation

// MARK: - Store Stock
//
// One product's stock at every open store (GET /products/:id/stock): the app's
// own batches, quantities only. Fetched when a product or receiving opens,
// never delta-synced. An empty list (a product that doesn't track stock, or a
// failed/offline fetch) shows nothing.

public struct StoreStock: Decodable, Equatable, Identifiable, Sendable {
    public let locationId: String
    public let locationName: String
    public let quantity: Int

    public var id: String { locationId }

    public init(locationId: String, locationName: String, quantity: Int) {
        self.locationId = locationId
        self.locationName = locationName
        self.quantity = quantity
    }

    /// Product detail lists the other stores; this one already has its own stock line.
    public static func others(_ stores: [StoreStock], currentLocationId: String?) -> [StoreStock] {
        stores.filter { $0.locationId != currentLocationId }
    }

    /// Out of stock here: the stores that have it are where to ask for a transfer.
    public func standsOut(hereQuantity: Int) -> Bool {
        hereQuantity <= 0 && quantity > 0
    }

    /// This store's fresh quantity — where receiving's "antes → después" starts.
    public static func here(_ stores: [StoreStock], currentLocationId: String?) -> Int? {
        stores.first { $0.locationId == currentLocationId }?.quantity
    }

    /// Receiving, next to the quantity: "Aquí 7 · Centro 0 · Sur 0".
    public static func summary(_ stores: [StoreStock], currentLocationId: String?) -> String? {
        guard !stores.isEmpty else { return nil }
        let here = stores.filter { $0.locationId == currentLocationId }.map { "Aquí \($0.quantity)" }
        let rest = others(stores, currentLocationId: currentLocationId).map { "\($0.locationName) \($0.quantity)" }
        return (here + rest).joined(separator: " · ")
    }
}

public struct StoreStockResponse: Decodable, Sendable {
    public let data: [StoreStock]
}
