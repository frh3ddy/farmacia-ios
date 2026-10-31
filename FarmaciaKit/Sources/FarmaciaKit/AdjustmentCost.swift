import Foundation

// MARK: - Adjustment Cost
//
// An adjustment that adds stock becomes a FIFO batch, which needs a unit cost:
// the API uses the product's last cost and, when there is none (e.g. a product
// created without initial stock), refuses with UNIT_COST_REQUIRED. Only then
// does the form ask for one. Removals are costed from FIFO batches, so they
// never take one.

public enum AdjustmentCost {
    /// `countChange` is the counted change for count types (nil until there is one);
    /// `costRequired` is whether the API has asked for a cost on this form.
    public static func asksForCost(isNegative: Bool, isVariable: Bool, countChange: Int?, costRequired: Bool) -> Bool {
        guard costRequired else { return false }
        if isVariable { return (countChange ?? 0) > 0 }
        return !isNegative
    }
}
