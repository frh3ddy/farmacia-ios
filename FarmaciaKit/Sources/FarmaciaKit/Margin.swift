import Foundation

// MARK: - Margin
//
// Profit as a share of the selling price — what the create-product and receiving
// forms preview while the user types a price and cost.

public enum Margin {
    /// `(price - cost) / price` as a percentage; nil without a positive price.
    public static func percent(price: Double, cost: Double) -> Double? {
        guard price > 0 else { return nil }
        return (price - cost) / price * 100
    }

    /// Healthy from 20%, thin from 10%, too low below that.
    public static func tone(forPercent percent: Double) -> Tone {
        if percent >= 20 { return .positive }
        if percent >= 10 { return .caution }
        return .critical
    }
}
