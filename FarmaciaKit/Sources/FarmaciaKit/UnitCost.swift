import Foundation

// MARK: - Unit Cost
//
// The one cost per unit the product detail shows, and that its margin uses:
// the latest cost from the preferred supplier (else the first on record), or
// the average cost of stock on hand when no supplier is on record. Carries its
// provenance so the screen can say where the number came from.
public struct UnitCost: Equatable, Sendable {
    public struct Supplier: Equatable, Sendable {
        public let id: String
        public let name: String
        public let cost: Double
        public let isPreferred: Bool
        /// When this supplier's current cost took effect (its last purchase).
        public let lastPurchase: Date?

        public init(id: String, name: String, cost: Double, isPreferred: Bool, lastPurchase: Date?) {
            self.id = id
            self.name = name
            self.cost = cost
            self.isPreferred = isPreferred
            self.lastPurchase = lastPurchase
        }
    }

    public enum Source: Equatable, Sendable {
        case supplier(name: String, lastPurchase: Date?)
        case average
    }

    public let cost: Double
    public let source: Source
    /// The picked supplier is the cheapest of two or more.
    public let isBestPrice: Bool
    /// More than one supplier: a list to open. With one, it's already on screen.
    public let showsAllSuppliers: Bool

    public static func pick(suppliers: [Supplier], averageCost: Double?) -> UnitCost? {
        guard let picked = suppliers.first(where: \.isPreferred) ?? suppliers.first else {
            return averageCost.map { UnitCost(cost: $0, source: .average, isBestPrice: false, showsAllSuppliers: false) }
        }
        let others = suppliers.filter { $0.id != picked.id }
        return UnitCost(
            cost: picked.cost,
            source: .supplier(name: picked.name, lastPurchase: picked.lastPurchase),
            isBestPrice: !others.isEmpty && others.allSatisfy { picked.cost <= $0.cost },
            showsAllSuppliers: suppliers.count > 1
        )
    }
}
