import Foundation

// MARK: - Stock Level
//
// A product's stock at this store, by meaning. With the API's `StockAlert`, only
// regular sellers alert (out / low); a slow mover at 0 is `.empty` (still
// "Agotado", but quiet), and a paused product is `.paused`. Without it (old
// server), the fixed cutoffs of the old list filters (≤ 0 out, 1–9 low).

public enum StockLevel: Equatable, Sendable {
    case out, low, ok
    /// At 0, but not a regular seller: no alert.
    case empty
    case paused(PauseReason?)

    public init(quantity: Int) {
        self = quantity <= 0 ? .out : quantity < 10 ? .low : .ok
    }

    public init(quantity: Int, alert: StockAlert?) {
        guard let alert else { self.init(quantity: quantity); return }
        if alert.paused {
            self = .paused(alert.pauseReason)
        } else if quantity <= 0 {
            self = alert.level == .out ? .out : .empty
        } else {
            self = alert.level == .low ? .low : .ok
        }
    }

    public var tone: Tone {
        switch self {
        case .out: .critical
        case .low: .caution
        case .ok, .empty, .paused: .neutral
        }
    }

    /// Badge text; nil when there's nothing to flag.
    public var label: String? {
        switch self {
        case .out, .empty: "Agotado"
        case .low: "Bajo"
        case .ok: nil
        case .paused(let reason): reason.map { "Pausado · \($0.label)" } ?? "Pausado"
        }
    }
}

// MARK: - Batch Age

public enum BatchAge {
    /// How long a batch has sat on the shelf, in the API aging service's buckets
    /// (0–30, 31–60, 61–90, 90+): up to 30 days fresh, up to 90 slow, then old.
    public static func tone(days: Int) -> Tone {
        if days <= 30 { return .positive }
        if days <= 90 { return .caution }
        return .critical
    }
}

// MARK: - Stock Tally
//
// Fallback counts for the Productos chips and the Alertas cards, from the rows on
// hand when the server's counts aren't in. Sin Stock is the stock state (every
// product at 0, alerting or quiet). A paused product counts only as paused, even
// with stock left (same buckets as GET /products/counts).

public struct StockTally: Equatable, Sendable {
    public var outOfStock = 0
    public var lowStock = 0
    public var inStock = 0
    /// nil when no row carries an alert (old server): there's no Pausados chip.
    public var paused: Int?

    public init(outOfStock: Int = 0, lowStock: Int = 0, inStock: Int = 0, paused: Int? = 0) {
        self.outOfStock = outOfStock
        self.lowStock = lowStock
        self.inStock = inStock
        self.paused = paused
    }

    /// Each row's on-hand quantity at this store and the API's alert, if any.
    public init(_ rows: [(quantity: Int, alert: StockAlert?)]) {
        var paused = 0
        var sawAlert = false
        for row in rows {
            sawAlert = sawAlert || row.alert != nil
            switch StockLevel(quantity: row.quantity, alert: row.alert) {
            case .out, .empty: outOfStock += 1
            case .low: lowStock += 1
            case .ok: inStock += 1
            case .paused: paused += 1
            }
        }
        self.paused = sawAlert ? paused : nil
    }
}
