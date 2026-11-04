import Foundation

// MARK: - Receiving Price
//
// Recibir inventario's "Actual" margin chip: the margin the product had at the
// old cost, applied to the new cost — the usual reaction to a supplier raising
// prices, in one tap.

public enum ReceivingPrice {
    /// The old cost: the supplier's last cost (same baseline as `CostChange`),
    /// else the average cost of the stock on hand.
    public static func oldCost(supplierLast: Double?, average: Double?) -> Double? {
        supplierLast ?? average
    }

    /// The current price's margin at the old cost, priced at the new cost.
    public static func keepingMargin(currentPrice: Double?, oldCost: Double?, newCost: Double?) -> Double? {
        guard let currentPrice, let oldCost, let newCost,
              let margin = Margin.percent(price: currentPrice, cost: oldCost)
        else { return nil }
        return PriceSuggestion.price(cost: newCost, marginPercent: margin)
    }
}
