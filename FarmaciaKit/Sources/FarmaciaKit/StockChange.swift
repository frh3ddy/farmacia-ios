import Foundation

// MARK: - Stock Change
//
// Which way a recorded adjustment moved stock, from its signed quantity (the
// API stores removals as negative). The type alone can't say: a count
// correction can go either way.

public enum StockChange: Equatable, Sendable {
    case added, removed, none

    public init(quantity: Int) {
        self = quantity > 0 ? .added : quantity < 0 ? .removed : .none
    }

    /// Added → positive, removed → critical, no change → caution.
    public var tone: Tone {
        switch self {
        case .added: .positive
        case .removed: .critical
        case .none: .caution
        }
    }
}
