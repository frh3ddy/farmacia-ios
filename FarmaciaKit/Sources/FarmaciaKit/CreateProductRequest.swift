import Foundation

// MARK: - Create Product Request
//
// POST /products. `clientRequestId` is one UUID per create the user is making
// (kept across retries of it), so a retry after a lost response gets the product
// already created instead of a second one. `soldAtAllLocations: false` sells the
// product only at `locationId` (e.g. a single toy) and hides it at other stores.

public struct CreateProductRequest: Encodable, Equatable, Sendable {
    public let name: String
    public let sku: String?
    public let description: String?
    public let sellingPrice: Double
    public let costPrice: Double?
    public let initialStock: Int?
    public let supplierId: String?
    public let locationId: String?
    public let syncToSquare: Bool
    public let soldAtAllLocations: Bool
    public let clientRequestId: String

    public init(
        name: String,
        sku: String?,
        description: String?,
        sellingPrice: Double,
        costPrice: Double?,
        initialStock: Int?,
        supplierId: String?,
        locationId: String?,
        syncToSquare: Bool,
        soldAtAllLocations: Bool = true,
        clientRequestId: String
    ) {
        self.name = name
        self.sku = sku
        self.description = description
        self.sellingPrice = sellingPrice
        self.costPrice = costPrice
        self.initialStock = initialStock
        self.supplierId = supplierId
        self.locationId = locationId
        self.syncToSquare = syncToSquare
        self.soldAtAllLocations = soldAtAllLocations
        self.clientRequestId = clientRequestId
    }
}
