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

    @Test("given an owner, should offer every filter")
    func owner() {
        #expect(ProductFilter.visible(canViewCosts: true) == ProductFilter.allCases)
    }

    @Test("given the Por Vencer filter while its data is unavailable, should say it couldn't load rather than \"no results\"")
    func unavailableEmptyState() {
        let empty = ProductFilter.expiringSoon.emptyState(risk: .unavailable)
        #expect(empty.title == "No Disponible")
        #expect(empty.message.contains("No se pudo cargar"))
    }

    @Test("given the Por Vencer filter with its data loaded and no matches, or any other filter, should say no results",
          arguments: [(ProductFilter.expiringSoon, RiskSet.loaded([])), (.lowStock, .unavailable), (.all, .loading)])
    func noResults(filter: ProductFilter, risk: RiskSet) {
        #expect(filter.emptyState(risk: risk).title == "Sin Resultados")
    }
}
