import SwiftUI
import FarmaciaKit

// MARK: - Amount Value

/// What an AmountField can hold: how it reads from the typed text, which
/// keyboard it needs, and its placeholder.
protocol AmountValue: Equatable {
    static var keyboard: UIKeyboardType { get }
    static var placeholder: String { get }
    /// The value in `text` (`AmountText.parse`), or nil when it isn't one.
    init?(parsing text: String)
    var amount: Double { get }
}

extension Double: AmountValue {
    static var keyboard: UIKeyboardType { .decimalPad }
    static var placeholder: String { "0.00" }
    init?(parsing text: String) {
        guard let amount = AmountText.parse(text) else { return nil }
        self = amount
    }
    var amount: Double { self }
}

extension Int: AmountValue {
    static var keyboard: UIKeyboardType { .numberPad }
    static var placeholder: String { "0" }
    /// Whole numbers only: "12.5" isn't a quantity (nil), not a silent 12.
    init?(parsing text: String) {
        guard let amount = AmountText.parse(text), let whole = Int(exactly: amount) else { return nil }
        self = whole
    }
    var amount: Double { Double(self) }
}
