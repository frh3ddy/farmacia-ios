import Foundation
import Testing
@testable import FarmaciaKit

/// The on-device product cache holds one row per product. Stock and price belong to a
/// store (the same for every role there); cost is never cached, so a role change at
/// the same store doesn't invalidate it. The cache outlives an app restart.
struct ProductCacheScopeTests {
    let centro = ProductCacheScope(locationId: "centro")

    @Test("given an owner then a cashier at the same store, should keep the cache")
    func roleChangeSameStore() {
        #expect(!ProductCacheScope(locationId: "centro").needsClear(storedKey: centro.key))
    }

    @Test("given another store, should clear")
    func otherStore() {
        #expect(ProductCacheScope(locationId: "norte").needsClear(storedKey: centro.key))
    }

    @Test("given no stored scope (first launch after this update, or an older cache that may hold costs), should clear")
    func noStoredScope() {
        #expect(centro.needsClear(storedKey: nil))
    }

    @Test("given a key stored by the previous version of this rule (store plus cost visibility), should clear")
    func previousRuleKey() {
        #expect(centro.needsClear(storedKey: "centro|costs"))
    }
}

struct CacheSweepTests {
    let start = Date(timeIntervalSince1970: 1_000)

    @Test("given a warm-up that reached the last page, rows not fetched since it started should be swept, rows fetched during it kept")
    func completedWalk() {
        #expect(CacheSweep.isStale(lastFetchedAt: start.addingTimeInterval(-1), walkStartedAt: start, walkCompleted: true))
        #expect(!CacheSweep.isStale(lastFetchedAt: start, walkStartedAt: start, walkCompleted: true))
        #expect(!CacheSweep.isStale(lastFetchedAt: start.addingTimeInterval(5), walkStartedAt: start, walkCompleted: true))
    }

    @Test("given a warm-up stopped by an error or cancellation, should sweep nothing")
    func partialWalk() {
        #expect(!CacheSweep.isStale(lastFetchedAt: start.addingTimeInterval(-3600), walkStartedAt: start, walkCompleted: false))
    }
}

struct BarcodeLookupTests {
    @Test("given two cached products with the same barcode, should ask the server instead of opening one")
    func shared() {
        #expect(BarcodeLookup.cacheDecision(matchCount: 2) == .askServer)
    }

    @Test("given exactly one match, should open it; given none, should ask the server")
    func singleOrNone() {
        #expect(BarcodeLookup.cacheDecision(matchCount: 1) == .open)
        #expect(BarcodeLookup.cacheDecision(matchCount: 0) == .askServer)
    }
}
