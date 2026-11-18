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

    /// The cost typed in Nuevo producto just before (scan flow, Recibir): the
    /// product's server record drops it without initial stock, so the receive
    /// form takes it from there. Zero (a gift) counts; only for the selected product.
    public mutating func prefill(_ cost: Double, forProductId productId: String) {
        guard productId == self.productId, cost >= 0 else { return }
        value = cost
    }

    /// The line under the cost field whenever there's no cost change to show (empty, the same
    /// cost, or only an average to compare with): the previous cost (`ReceivingPrice.previous`),
    /// so it's still there to type from after the field is cleared. Outside the field (a
    /// placeholder was cut off in the narrow field), so with its "$".
    public static func hint(previous: ReceivingPrice.PreviousCost?) -> String? {
        previous.map { previous in
            let cost = "Anterior " + ReportFormat.currency(previous.cost)
            // Another supplier's cost (`ReceivingPrice.previous`): say whose.
            return previous.supplierName.map { "\(cost) · \($0)" } ?? cost
        }
    }

    /// Fills in a supplier's cost (`SelectedSupplierCost.lastCost`): only a positive cost, only into an empty
    /// field, only for the selected product. Returns whether it filled.
    @discardableResult
    public mutating func offerSupplierCost(_ cost: Double, forProductId productId: String) -> Bool {
        guard productId == self.productId, value == nil, cost > 0 else { return false }
        value = cost
        return true
    }
}

/// The selected supplier's last cost for this product, whichever arrives first: the
/// selection (a run supplier, or a tap while loading) or the product's supplier costs.
/// Each event returns the cost to offer (`ReceivingCost.offerSupplierCost`), so a supplier
/// picked before the costs load still gets its cost (and the "Anterior" hint shows it, not
/// the average). Not discardable: ignoring it was the bug.
public struct SelectedSupplierCost: Equatable, Sendable {
    public private(set) var selectedId: String?
    private var costs: [String: Double] = [:]

    public init() {}

    public var lastCost: Double? { selectedId.flatMap { costs[$0] } }

    public mutating func select(_ supplierId: String?) -> Double? {
        selectedId = supplierId
        return lastCost
    }

    /// GET /products/:id/suppliers in list order: a supplier listed twice keeps its first cost, as the list shows it.
    public mutating func costsLoaded(_ suppliers: [(id: String, cost: Double)]) -> Double? {
        costs = Dictionary(suppliers.map { ($0.id, $0.cost) }, uniquingKeysWith: { first, _ in first })
        return lastCost
    }
}
