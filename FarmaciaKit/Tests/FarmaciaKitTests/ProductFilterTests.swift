import Foundation
import Testing
@testable import FarmaciaKit

/// The Por Vencer / En Riesgo chips filter by product ids loaded separately from the
/// list. A load that failed must not read as "nothing expiring".
struct RiskSetTests {
    @Test("given the expiring load failed, should be unavailable, not an empty set")
    func failure() {
        let after = RiskSet.loaded(["p1"]).after(failure: NetworkError.serverError(message: "boom"))
        #expect(after == .unavailable)
        #expect(after.ids.isEmpty)
    }

    @Test("given the load was cancelled, should keep the previous state",
          arguments: [NetworkError.cancelled, CancellationError()] as [Error])
    func cancelled(error: Error) {
        #expect(RiskSet.loaded(["p1"]).after(failure: error) == .loaded(["p1"]))
        #expect(RiskSet.loading.after(failure: error) == .loading)
    }

    @Test("given unavailable or still loading, chip count should be nil; given loaded, the number of ids")
    func count() {
        #expect(RiskSet.unavailable.count == nil)
        #expect(RiskSet.loading.count == nil)
        #expect(RiskSet.loaded(["p1", "p2"]).count == 2)
        #expect(RiskSet.loaded([]).count == 0)
    }
}

struct ProductFilterTests {
    @Test("given a cashier, should offer Por Vencer and hide En Riesgo and Margen Bajo (both come from cost)")
    func cashier() {
        let filters = ProductFilter.visible(canViewCosts: false)
        #expect(filters.contains(.expiringSoon))
        #expect(!filters.contains(.atRisk))
        #expect(!filters.contains(.lowMargin))
    }

    @Test("given an owner and a server that counts paused products, should offer every filter")
    func owner() {
        #expect(ProductFilter.visible(canViewCosts: true, showsPaused: true) == ProductFilter.allCases)
    }

    @Test("given the Pausados chip, should send filter=paused, in a neutral tone")
    func paused() {
        #expect(ProductFilter.paused.rawValue == "Pausados")
        #expect(ProductFilter.paused.apiValue == "paused")
        #expect(ProductFilter.paused.tone == .neutral)
    }

    @Test("given a server without paused counts (old server), should hide Pausados and fall back from it to Todos")
    func pausedOldServer() {
        #expect(!ProductFilter.visible(canViewCosts: true).contains(.paused))
        #expect(ProductFilter.visible(canViewCosts: false, showsPaused: true).contains(.paused))
        #expect(ProductFilter.coerced(.paused, canViewCosts: true) == .all)
        #expect(ProductFilter.coerced(.paused, canViewCosts: false, showsPaused: true) == .paused)
    }

    @Test("given En Riesgo or Margen Bajo active and the role becomes cashier, should fall back to Todos",
          arguments: [ProductFilter.atRisk, .lowMargin])
    func coercedForCashier(filter: ProductFilter) {
        #expect(ProductFilter.coerced(filter, canViewCosts: false) == .all)
    }

    @Test("given a filter the role can see, should keep it",
          arguments: [(ProductFilter.expiringSoon, false), (.lowStock, false), (.atRisk, true), (.lowMargin, true)])
    func coercedKeeps(filter: ProductFilter, canViewCosts: Bool) {
        #expect(ProductFilter.coerced(filter, canViewCosts: canViewCosts) == filter)
    }
}
