import Foundation
import Testing
@testable import FarmaciaKit

/// The one cost per unit the product detail shows (and its margin uses), with where it came from.
struct UnitCostTests {
    let nov1 = Date(timeIntervalSince1970: 1_793_000_000)

    func supplier(_ id: String, cost: Double, preferred: Bool = false, lastPurchase: Date? = nil) -> UnitCost.Supplier {
        .init(id: id, name: id.capitalized, cost: cost, isPreferred: preferred, lastPurchase: lastPurchase)
    }

    @Test("given a preferred supplier at 98 and average 105, should pick 98 from that supplier")
    func preferredWins() throws {
        let pick = try #require(UnitCost.pick(
            suppliers: [supplier("fanasa", cost: 90), supplier("simi", cost: 98, preferred: true, lastPurchase: nov1)],
            averageCost: 105))
        #expect(pick.cost == 98)
        #expect(pick.source == .supplier(name: "Simi", lastPurchase: nov1))
    }

    @Test("given no preferred supplier, should pick the first one (as the header did)")
    func firstWithoutPreferred() throws {
        let pick = try #require(UnitCost.pick(suppliers: [supplier("simi", cost: 98), supplier("fanasa", cost: 90)], averageCost: nil))
        #expect(pick.cost == 98)
    }

    @Test("given no suppliers, should fall back to the average cost")
    func averageFallback() throws {
        let pick = try #require(UnitCost.pick(suppliers: [], averageCost: 105))
        #expect(pick.cost == 105)
        #expect(pick.source == .average)
        #expect(pick.isBestPrice == false)
    }

    @Test("given no suppliers and no average, should be nil")
    func nothing() {
        #expect(UnitCost.pick(suppliers: [], averageCost: nil) == nil)
    }

    @Test("given one supplier, should hide the all-suppliers link and the best-price badge")
    func singleSupplier() throws {
        let pick = try #require(UnitCost.pick(suppliers: [supplier("simi", cost: 98)], averageCost: nil))
        #expect(pick.showsAllSuppliers == false)
        #expect(pick.isBestPrice == false)
    }

    @Test("given the picked supplier is the cheapest of two, should mark it best price")
    func bestPrice() throws {
        let cheapest = try #require(UnitCost.pick(
            suppliers: [supplier("simi", cost: 98, preferred: true), supplier("fanasa", cost: 110)], averageCost: nil))
        #expect(cheapest.isBestPrice)
        #expect(cheapest.showsAllSuppliers)
        let dearer = try #require(UnitCost.pick(
            suppliers: [supplier("simi", cost: 120, preferred: true), supplier("fanasa", cost: 110)], averageCost: nil))
        #expect(dearer.isBestPrice == false)
    }
}
