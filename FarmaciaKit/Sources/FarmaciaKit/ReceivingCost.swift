import Foundation

// MARK: - Receiving Cost
//
// The receive form's unit cost and the product it belongs to. A cost is per
// product, so picking another product clears it; a supplier's cost fills it in
// only for the product still selected, so a slow response for the previous
// product can't record a receiving at that product's cost.

public struct ReceivingCost: Equatable, Sendable {
    public var value: Double?
    private var productId: String?

    public init() {}

    public mutating func productChanged(to productId: String?) {
        guard productId != self.productId else { return }
        self.productId = productId
        value = nil
    }

    /// Fills in a supplier's cost: only a positive cost, only into an empty
    /// field, only for the selected product. Returns whether it filled.
    @discardableResult
    public mutating func offerSupplierCost(_ cost: Double, forProductId productId: String) -> Bool {
        guard productId == self.productId, value == nil, cost > 0 else { return false }
        value = cost
        return true
    }
}
