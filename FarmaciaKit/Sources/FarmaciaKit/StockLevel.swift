import Foundation

// MARK: - Stock Level
//
// A product's stock at this store, by meaning. Same cutoffs as the API's list
// filters (outOfStock ≤ 0, lowStock 1–9), so a row's badge agrees with the
// "Stock Bajo" / "Sin Stock" chips.

public enum StockLevel: Equatable, Sendable {
    case out, low, ok

    public init(quantity: Int) {
        self = quantity <= 0 ? .out : quantity < 10 ? .low : .ok
    }

    public var tone: Tone {
        switch self {
        case .out: .critical
        case .low: .caution
        case .ok: .neutral
        }
    }

    /// Badge text; nil when there's nothing to flag.
    public var label: String? {
        switch self {
        case .out: "Agotado"
        case .low: "Bajo"
        case .ok: nil
        }
    }
}

// MARK: - Batch Age

public enum BatchAge {
    /// How long a batch has sat on the shelf: under 30 days fresh, under 90 slow, then old.
    public static func tone(days: Int) -> Tone {
        if days < 30 { return .positive }
        if days < 90 { return .caution }
        return .critical
    }
}
