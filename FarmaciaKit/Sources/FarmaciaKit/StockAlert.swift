import Foundation

// MARK: - Stock Alert
//
// The API's per-product, per-store alert (docs/stock-alerts-design.md). Only
// regular sellers alert: out = a regular seller at 0, low = below 14 days of
// cover and below its normal level. A paused product never alerts. Optional on
// `Product`: an old server doesn't send it, and callers fall back to the fixed
// `StockLevel(quantity:)` cutoffs.

public struct StockAlert: Codable, Hashable, Sendable {
    public enum Level: String, Codable, Sendable {
        case none, low, out
    }

    public let level: Level
    /// Lost sales per day; higher sorts first in Alertas.
    public let priority: Double
    public let paused: Bool
    public let pauseReason: PauseReason?
    /// When this store's stock last reached 0; nil while in stock or unknown.
    public let zeroSince: Date?

    private enum CodingKeys: String, CodingKey {
        case level, priority, paused, pauseReason, zeroSince
    }

    public init(level: Level, priority: Double = 0, paused: Bool = false, pauseReason: PauseReason? = nil, zeroSince: Date? = nil) {
        self.level = level
        self.priority = priority
        self.paused = paused
        self.pauseReason = pauseReason
        self.zeroSince = zeroSince
    }

    // Unknown level or reason values decode as none / nil: a new server value
    // must not fail the whole product list.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = Level(rawValue: try c.decode(String.self, forKey: .level)) ?? .none
        priority = try c.decodeIfPresent(Double.self, forKey: .priority) ?? 0
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        pauseReason = try c.decodeIfPresent(String.self, forKey: .pauseReason).flatMap(PauseReason.init(rawValue:))
        zeroSince = try c.decodeIfPresent(Date.self, forKey: .zeroSince)
    }
}

/// Why a product is paused at a store. Paused isn't discontinued: it may be restocked,
/// and it resumes itself on any receiving or received transfer at that store, whatever the stock.
public enum PauseReason: String, Codable, CaseIterable, Sendable {
    case supplierUnavailable = "SUPPLIER_UNAVAILABLE"
    case replacedByEquivalent = "REPLACED_BY_EQUIVALENT"
    case slowMover = "SLOW_MOVER"
    case other = "OTHER"

    public var label: String {
        switch self {
        case .supplierUnavailable: "Proveedor sin surtido"
        case .replacedByEquivalent: "Reemplazado por equivalente"
        case .slowMover: "Se vende poco"
        case .other: "Otro"
        }
    }

    /// The pause form asks which product replaced it.
    public var requiresProduct: Bool { self == .replacedByEquivalent }
}

extension StockAlert {
    /// "Agotado hace 3 días" on Sin Stock rows; nil when the date is unknown.
    public func zeroSinceText(now: Date = Date(), timeZone: TimeZone = .current) -> String? {
        zeroSince.map { "Agotado \(DisplayDate.relative($0, now: now, timeZone: timeZone))" }
    }
}

// The offline cache keeps the alert as one encoded value (an old row has none).
extension StockAlert {
    public var cacheData: Data? { try? JSONEncoder().encode(self) }

    public init?(cacheData: Data?) {
        guard let cacheData, let alert = try? JSONDecoder().decode(StockAlert.self, from: cacheData) else { return nil }
        self = alert
    }
}

extension StockLevel {
    /// The row badge: "Agotado hace 3 días" when the API knows since when, else the label.
    public static func badgeText(quantity: Int, alert: StockAlert?, now: Date = Date(), timeZone: TimeZone = .current) -> String? {
        let level = StockLevel(quantity: quantity, alert: alert)
        switch level {
        case .out, .empty: return alert?.zeroSinceText(now: now, timeZone: timeZone) ?? level.label
        default: return level.label
        }
    }
}
