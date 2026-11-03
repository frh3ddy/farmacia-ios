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

/// After a scan the cache couldn't settle, the server's exact search decides the
/// next step of the scan flow: open the product, choose among several, or create
/// one with the scanned code. An error offers to create too.
struct BarcodeServerDecisionTests {
    @Test("given an exact match, should open it")
    func exactMatch() {
        #expect(BarcodeLookup.serverDecision(exactMatch: true, resultCount: 3) == .open)
    }

    @Test("given one result that isn't exact, should open it")
    func singleFuzzy() {
        #expect(BarcodeLookup.serverDecision(exactMatch: false, resultCount: 1) == .open)
    }

    @Test("given several results, should list them to choose")
    func several() {
        #expect(BarcodeLookup.serverDecision(exactMatch: false, resultCount: 2) == .choose)
        #expect(BarcodeLookup.serverDecision(exactMatch: nil, resultCount: 4) == .choose)
    }

    @Test("given no results, should offer to create a product with the code")
    func none() {
        #expect(BarcodeLookup.serverDecision(exactMatch: nil, resultCount: 0) == .create)
    }
}
