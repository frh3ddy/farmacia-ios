import Foundation

// MARK: - Product Figures
//
// What a product card shows from a list row. Cost, stock value and margin only for
// roles that can view costs; no stock for items that don't track it (Yastás).

public struct ProductFigures: Equatable, Sendable {
    public let price: Double?
    /// Average cost of the stock on hand at this store (the API's `averageCost`).
    public let cost: Double?
    public let stock: Int?
    /// Stock at cost: `cost × stock`, only with stock on hand.
    public let stockValue: Double?
    public let marginPercent: Double?

    /// `tracksInventory` nil counts as tracked (only Yastás items say false).
    public init(price: Double?, cost: Double?, stock: Int?, tracksInventory: Bool?, canViewCosts: Bool) {
        let tracks = tracksInventory != false
        let cost = canViewCosts ? cost : nil
        let stock = tracks ? stock : nil
        self.price = price
        self.cost = cost
        self.stock = stock
        if let cost, let stock, stock > 0 { stockValue = cost * Double(stock) } else { stockValue = nil }
        if let price, let cost { marginPercent = Margin.percent(price: price, cost: cost) } else { marginPercent = nil }
    }
}
