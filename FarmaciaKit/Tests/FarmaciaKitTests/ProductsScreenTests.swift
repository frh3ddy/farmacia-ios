import Foundation
import Testing
@testable import FarmaciaKit

/// Productos is search-first: staff search or scan, they don't scroll the catalog.
struct ProductsScreenTests {
    @Test("given no search and no chip, should load no list (the screen shows recent products)")
    func start() {
        #expect(ProductsScreen.query(locationId: "loc", search: "  ", filter: nil) == nil)
    }

    @Test("given a search, a chip or Ver todo, should load that list")
    func lists() {
        #expect(ProductsScreen.query(locationId: "loc", search: "para", filter: nil)
                == ProductListQuery(locationId: "loc", search: "para"))
        #expect(ProductsScreen.query(locationId: "loc", search: "", filter: .outOfStock)
                == ProductListQuery(locationId: "loc", search: nil, filter: .outOfStock))
        #expect(ProductsScreen.query(locationId: "loc", search: "", filter: .all)?.isCatalog == true)
    }

    @Test("given no store yet, should load nothing")
    func noStore() {
        #expect(ProductsScreen.query(locationId: nil, search: "para", filter: .all) == nil)
    }

    @Test("given an owner and a server with paused counts, chips should be the short lists only (no Todos, no In Stock)")
    func chips() {
        #expect(ProductFilter.chips(canViewCosts: true, showsPaused: true)
                == [.outOfStock, .lowStock, .expiringSoon, .paused, .atRisk, .lowMargin])
        #expect(ProductFilter.chips(canViewCosts: false, showsPaused: false) == [.outOfStock, .lowStock, .expiringSoon])
    }
}

struct RecentProductsTests {
    @Test("given A, B, then A opened again, should list A, B")
    func reopen() {
        var ids: [String] = []
        for id in ["B", "A", "B", "A"] { ids = RecentProducts.adding(id, to: ids) }
        #expect(ids == ["A", "B"])
    }

    @Test("given 10 recents, the 11th should drop the oldest")
    func cap() {
        let ten = (1...10).map { "p\($0)" } // p1 newest
        #expect(RecentProducts.adding("new", to: ten) == ["new"] + (1...9).map { "p\($0)" })
    }

    @Test("given cached rows in any order and an id no longer in the catalog, should show them in recent order and skip the missing one")
    func ordered() {
        struct Row: Identifiable, Equatable { let id: String }
        let rows = [Row(id: "a"), Row(id: "b")]
        #expect(RecentProducts.ordered(rows, by: ["b", "gone", "a"]) == [Row(id: "b"), Row(id: "a")])
    }
}
