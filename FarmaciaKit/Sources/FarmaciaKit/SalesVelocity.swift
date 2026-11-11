import Foundation

// MARK: - Sales Velocity
//
// GET /products/:id/sales-velocity: how fast a product sells at a store, net of
// returns (Square history ∪ live sales). The server counts the days, so the
// text needs no time-zone math here.
public struct SalesVelocity: Decodable, Equatable, Sendable {
    public let lastSoldAt: Date?
    public let unitsLast30d: Int
    public let unitsLast90d: Int
    public let daysSinceLastSale: Int?

    public init(lastSoldAt: Date?, unitsLast30d: Int, unitsLast90d: Int, daysSinceLastSale: Int?) {
        self.lastSoldAt = lastSoldAt
        self.unitsLast30d = unitsLast30d
        self.unitsLast90d = unitsLast90d
        self.daysSinceLastSale = daysSinceLastSale
    }

    /// "12 vendidas en 30 días · última venta hace 2 días", "Sin ventas en 30 días · 4 en 90 días",
    /// "Sin ventas en 90 días · última venta hace 200 días", "Sin ventas registradas".
    public var text: String {
        guard let days = daysSinceLastSale else { return "Sin ventas registradas" }
        let last = "última venta \(days <= 0 ? "hoy" : days == 1 ? "ayer" : "hace \(days) días")"
        if unitsLast30d > 0 {
            return "\(unitsLast30d) \(unitsLast30d == 1 ? "vendida" : "vendidas") en 30 días · \(last)"
        }
        if unitsLast90d > 0 { return "Sin ventas en 30 días · \(unitsLast90d) en 90 días" }
        return "Sin ventas en 90 días · \(last)"
    }

    /// Dead stock (units on hand, nothing sold in 90 days, or ever) → caution; otherwise neutral.
    public func tone(stockOnHand: Int) -> Tone {
        stockOnHand > 0 && unitsLast90d == 0 ? .caution : .neutral
    }
}
