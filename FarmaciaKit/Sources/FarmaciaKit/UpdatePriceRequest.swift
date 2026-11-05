import Foundation

// MARK: - Update Price Request
//
// PATCH /products/:id/price. "Every store" is sent whether or not the change
// goes to Square: the app's price for the other stores changes either way.
// Absent means this store only (a manager's "every store" is refused).

public struct UpdatePriceRequest: Encodable, Equatable, Sendable {
    public let sellingPrice: Double
    public let locationId: String?
    public let syncToSquare: Bool
    public let applyToAllLocations: Bool?

    public init(sellingPrice: Double, locationId: String?, syncToSquare: Bool, applyToAllLocations: Bool) {
        self.sellingPrice = sellingPrice
        self.locationId = locationId
        self.syncToSquare = syncToSquare
        self.applyToAllLocations = applyToAllLocations ? true : nil
    }
}
