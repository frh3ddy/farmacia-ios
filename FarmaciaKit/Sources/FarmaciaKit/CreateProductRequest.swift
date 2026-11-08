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
    /// The barcode (8/12/13/14 digits); the server sends it to Square as the variation's `upc`.
    public let gtin: String?
    public let description: String?
    public let sellingPrice: Double
    public let costPrice: Double?
    public let initialStock: Int?
    public let supplierId: String?
    public let locationId: String?
    public let syncToSquare: Bool
    public let soldAtAllLocations: Bool
    /// The initial stock's lote and caducidad (LocalDay YYYY-MM-DD); only with stock, since the API refuses them without.
    public let batchNumber: String?
    public let expiryDate: String?
    public let clientRequestId: String
    /// The server trims a lote, then keeps its first 100 characters.
    public static let lotMaxLength = 100

    public init(
        name: String,
        sku: String?,
        gtin: String? = nil,
        description: String?,
        sellingPrice: Double,
        costPrice: Double?,
        initialStock: Int?,
        supplierId: String?,
        locationId: String?,
        syncToSquare: Bool,
        soldAtAllLocations: Bool = true,
        batchNumber: String = "",
        expiryDate: Date? = nil,
        clientRequestId: String
    ) {
        self.name = name
        self.sku = sku
        self.gtin = gtin
        self.description = description
        self.sellingPrice = sellingPrice
        self.costPrice = costPrice
        self.initialStock = initialStock
        self.supplierId = supplierId
        self.locationId = locationId
        self.syncToSquare = syncToSquare
        self.soldAtAllLocations = soldAtAllLocations
        let lot = String(batchNumber.trimmingCharacters(in: .whitespaces).prefix(Self.lotMaxLength))
        self.batchNumber = initialStock == nil || lot.isEmpty ? nil : lot
        self.expiryDate = initialStock == nil ? nil : expiryDate.map { LocalDay.string(from: $0) }
        self.clientRequestId = clientRequestId
    }
}
