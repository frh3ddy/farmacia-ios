import Foundation

// MARK: - Receive Inventory Request
//
// POST /inventory/receive. `clientRequestId` is one UUID per receiving the
// user is entering, kept across retries of it, so a retry after a lost
// response gets the receiving already recorded instead of a second batch.

public struct ReceiveInventoryRequest: Encodable, Equatable, Sendable {
    public let locationId: String
    public let productId: String
    public let quantity: Int
    public let unitCost: Double
    public let supplierId: String?
    public let invoiceNumber: String?
    public let batchNumber: String?
    public let expiryDate: String?  // LocalDay YYYY-MM-DD
    public let notes: String?
    public let syncToSquare: Bool
    public let sellingPrice: Double?
    public let syncPriceToSquare: Bool?
    public let clientRequestId: String

    /// Blank text fields are sent as absent; a new selling price is always synced to Square.
    public init(
        locationId: String,
        productId: String,
        quantity: Int,
        unitCost: Double,
        supplierId: String?,
        invoiceNumber: String,
        batchNumber: String,
        expiryDate: Date?,
        notes: String,
        sellingPrice: Double?,
        clientRequestId: String
    ) {
        self.locationId = locationId
        self.productId = productId
        self.quantity = quantity
        self.unitCost = unitCost
        self.supplierId = supplierId
        self.invoiceNumber = invoiceNumber.isEmpty ? nil : invoiceNumber
        self.batchNumber = batchNumber.isEmpty ? nil : batchNumber
        self.expiryDate = expiryDate.map { LocalDay.string(from: $0) }
        self.notes = notes.isEmpty ? nil : notes
        self.syncToSquare = true
        self.sellingPrice = sellingPrice
        self.syncPriceToSquare = sellingPrice != nil ? true : nil
        self.clientRequestId = clientRequestId
    }
}
