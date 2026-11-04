import Foundation

// MARK: - Price Suggestion
//
// The selling price that gives a margin (on the price, like `Margin.percent`)
// at a cost, rounded up to the next $0.50 so it reads like a shelf price.
// The margin chips in Nuevo producto and Recibir inventario use it.

public enum PriceSuggestion {
    /// The chips offered once a cost is entered.
    public static let chips: [Double] = [30, 40, 50]

    /// nil for a margin of 100% or more (no price gives it) or a cost ≤ 0.
    public static func price(cost: Double, marginPercent: Double) -> Double? {
        guard cost > 0, marginPercent < 100 else { return nil }
        let exact = cost / (1 - marginPercent / 100)
        // To cents first: 21 / 0.7 is 30.000000000000004, which must stay 20.00.
        let cents = (exact * 100).rounded()
        return (cents / 50).rounded(.up) * 0.5
    }
}
