import Foundation

// MARK: - Adjustment Requests
//
// POST /inventory/adjustments (generic) and its quick routes (damage, theft,
// count-correction, …). `clientRequestId` is one UUID per adjustment the user
// is making, kept across retries of it, so a retry after a lost response gets
// the adjustment already recorded instead of a second one.

public struct CreateAdjustmentRequest: Encodable, Equatable, Sendable {
    public let locationId: String
    public let productId: String
    public let type: String
    public let quantity: Int
    public let reason: String?
    public let notes: String?
    public let unitCost: Double?
    public let effectiveDate: String?  // LocalDay YYYY-MM-DD
    public let adjustedBy: String?
    public let syncToSquare: Bool?
    public let clientRequestId: String

    public init(
        locationId: String,
        productId: String,
        type: String,
        quantity: Int,
        reason: String?,
        notes: String?,
        unitCost: Double?,
        effectiveDate: String?,
        adjustedBy: String?,
        syncToSquare: Bool?,
        clientRequestId: String
    ) {
        self.locationId = locationId
        self.productId = productId
        self.type = type
        self.quantity = quantity
        self.reason = reason
        self.notes = notes
        self.unitCost = unitCost
        self.effectiveDate = effectiveDate
        self.adjustedBy = adjustedBy
        self.syncToSquare = syncToSquare
        self.clientRequestId = clientRequestId
    }
}

/// A quick-route adjustment. For a count correction, `countedQuantity` is the
/// shelf total and the API derives the change from its own stock; `quantity`
/// (the on-screen preview) is only read by an API that predates it.
public struct QuickAdjustmentRequest: Encodable, Equatable, Sendable {
    public let locationId: String
    public let productId: String
    public let quantity: Int
    public let countedQuantity: Int?
    public let reason: String?
    public let notes: String?
    public let syncToSquare: Bool?
    public let clientRequestId: String

    public init(
        locationId: String,
        productId: String,
        quantity: Int,
        countedQuantity: Int? = nil,
        reason: String?,
        notes: String?,
        syncToSquare: Bool?,
        clientRequestId: String
    ) {
        self.locationId = locationId
        self.productId = productId
        self.quantity = quantity
        self.countedQuantity = countedQuantity
        self.reason = reason
        self.notes = notes
        self.syncToSquare = syncToSquare
        self.clientRequestId = clientRequestId
    }
}
