import Foundation

// MARK: - Margin Pick
//
// The margin chip a form has selected. While picked, the price follows the
// cost (same margin); typing a different price releases the chip.

public struct MarginPick: Equatable, Sendable {
    public var selected: Double?

    public init(selected: Double? = nil) {
        self.selected = selected
    }

    public func price(forCost cost: Double?) -> Double? {
        guard let selected, let cost else { return nil }
        return PriceSuggestion.price(cost: cost, marginPercent: selected)
    }

    /// A price the user typed keeps the chip only if it's the chip's own price.
    public mutating func priceTyped(_ price: Double?, cost: Double?) {
        if price != self.price(forCost: cost) { selected = nil }
    }
}
