import Foundation

// MARK: - Stock Impact
//
// What an adjustment or count will do to a store's stock, shown before the
// user saves ("42 → 39 (−3)"). The API works out the real change from its
// own stock; this is the preview.

public struct StockImpact: Equatable, Sendable {
    /// Stock on hand now, when known.
    public let before: Int?
    /// Signed: removals are negative.
    public let change: Int

    /// nil when nothing would change.
    public init?(before: Int?, change: Int?) {
        guard let change, change != 0 else { return nil }
        self.before = before
        self.change = change
    }

    public var after: Int? { before.map { $0 + change } }

    /// A removal larger than the stock on hand.
    public var exceedsStock: Bool { (after ?? 0) < 0 }

    public var tone: Tone { change > 0 ? .positive : .critical }

    /// "+10" / "−3" (a real minus sign).
    public var changeText: String {
        change > 0 ? "+\(change)" : "−\(abs(change))"
    }

    public var summary: String {
        guard let before, let after else { return "\(changeText) unidades" }
        return "\(before) → \(after) (\(changeText))"
    }
}
