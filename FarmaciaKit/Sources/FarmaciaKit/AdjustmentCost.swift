import Foundation

// MARK: - Adjustment Cost
//
// An adjustment that adds stock becomes a FIFO batch, which needs a unit cost:
// the API falls back to the product's last cost and rejects the adjustment when
// there is none (e.g. a product created without initial stock). Removals are
// costed from FIFO batches, so they never take one.

public enum AdjustmentCost {
    /// `countChange` is the counted change for count types (nil until there is one).
    public static func asksForCost(isNegative: Bool, isVariable: Bool, countChange: Int?) -> Bool {
        if isVariable { return (countChange ?? 0) > 0 }
        return !isNegative
    }
}
