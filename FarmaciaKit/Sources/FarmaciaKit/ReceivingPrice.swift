import Foundation

// MARK: - Receiving Price
//
// Recibir inventario's "Actual" margin chip: the margin the product had at the
// old cost, applied to the new cost — the usual reaction to a supplier raising
// prices, in one tap.

public enum ReceivingPrice {
    /// A previous cost, and whose it is when it isn't the selected supplier's.
    public struct PreviousCost: Equatable, Sendable {
        public let cost: Double
        public let supplierName: String?

        public init(cost: Double, supplierName: String?) {
            self.cost = cost
            self.supplierName = supplierName
        }
    }

    /// The newest receiving with a cost (GET /inventory/receive/product/:id, newest first;
    /// `unitCost` a decimal string): a $0 gift is skipped, not a reason to fall back to the average.
    public static func lastReceiving(newestFirst rows: [(unitCost: String, supplierName: String?)]) -> PreviousCost? {
        for row in rows {
            if let cost = Double(row.unitCost), cost > 0 { return PreviousCost(cost: cost, supplierName: row.supplierName) }
        }
        return nil
    }

    /// The cost to compare a receiving with (the "Anterior" hint, "vs último", the "Actual"
    /// chip): the selected supplier's last cost; else the latest receiving's, from whichever
    /// supplier (a supplier new to this product has none); else the average. A $0 (a gift)
    /// is no baseline.
    ///
    /// `onRecord`: the product's supplier cost the detail screen shows (`supplierOnRecord`), after
    /// the latest receiving: stock loaded by the migration has suppliers and costs but no receivings.
    public static func previous(supplierLast: Double?, lastReceiving: PreviousCost?,
                                onRecord: PreviousCost? = nil, average: Double?) -> PreviousCost? {
        if let supplierLast { return PreviousCost(cost: supplierLast, supplierName: nil) }
        if let lastReceiving, lastReceiving.cost > 0 { return lastReceiving }
        if let onRecord, onRecord.cost > 0 { return onRecord }
        return average.map { PreviousCost(cost: $0, supplierName: nil) }
    }

    /// The product's suppliers on record, picked as the detail screen does (`UnitCost.pick`:
    /// the preferred, else the first), named.
    public static func supplierOnRecord(_ suppliers: [UnitCost.Supplier]) -> PreviousCost? {
        guard let pick = UnitCost.pick(suppliers: suppliers, averageCost: nil),
              case .supplier(let name, _) = pick.source else { return nil }
        return PreviousCost(cost: pick.cost, supplierName: name)
    }

    /// The current price's margin at the old cost, priced at the new cost.
    public static func keepingMargin(currentPrice: Double?, oldCost: Double?, newCost: Double?) -> Double? {
        guard let currentPrice, let oldCost, let newCost,
              let margin = Margin.percent(price: currentPrice, cost: oldCost)
        else { return nil }
        return PriceSuggestion.price(cost: newCost, marginPercent: margin)
    }
}
