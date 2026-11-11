import Foundation

// MARK: - Pause Suggestion
//
// A product the sales and stock history say could be paused at this store
// (GET /inventory/pause-suggestions). Never applied by itself: a person reads the
// evidence in `reasonText` and pauses or dismisses it.

public struct PauseSuggestion: Decodable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Decodable, Sendable {
        /// At 0 for a long time and nobody bought it in the window.
        case noSalesAtZero = "NO_SALES_AT_ZERO"
        /// Sells a little and keeps running out.
        case slowWithStockouts = "SLOW_WITH_STOCKOUTS"
        /// At 0 while an equivalent keeps selling.
        case equivalentSelling = "EQUIVALENT_SELLING"
    }

    public struct Item: Decodable, Equatable, Sendable {
        public let id: String
        public let name: String
    }

    public struct Equivalent: Decodable, Equatable, Sendable {
        public let id: String
        public let name: String
        /// Units the equivalent sold since this product reached 0.
        public let unitsSince: Int
    }

    public let product: Item
    public let kind: Kind
    public let lastSoldAt: Date?
    public let unitsInWindow: Int
    public let daysAtZero: Int
    public let stockOuts: Int
    public let equivalent: Equivalent?

    /// One product can have more than one kind of suggestion.
    public var id: String { "\(product.id)-\(kind.rawValue)" }

    /// The evidence, e.g. "Sin ventas desde 3 mar 2026 · 0 en 90 días · 120 días en 0".
    public func reasonText(windowDays: Int = 90, timeZone: TimeZone = .current) -> String {
        let atZero = daysAtZero == 1 ? "1 día en 0" : "\(daysAtZero) días en 0"
        switch kind {
        case .noSalesAtZero:
            guard let lastSoldAt else { return "Sin ventas registradas · \(atZero)" }
            return "Sin ventas desde \(DisplayDate.day(lastSoldAt, timeZone: timeZone)) · \(unitsInWindow) en \(windowDays) días · \(atZero)"
        case .slowWithStockouts:
            let sold = unitsInWindow == 1 ? "1 vendida" : "\(unitsInWindow) vendidas"
            let outs = stockOuts == 1 ? "se agotó 1 vez" : "se agotó \(stockOuts) veces"
            return "\(sold) en \(windowDays) días · \(outs) · \(atZero)"
        case .equivalentSelling:
            guard let equivalent else { return atZero }
            return "Su equivalente \(equivalent.name) vendió \(equivalent.unitsSince) desde que se agotó · \(atZero)"
        }
    }
}
