import Foundation
import Testing
@testable import FarmaciaKit

struct ProductCountsTests {
    func decode(_ json: String) throws -> ProductCountsResponse {
        try JSONDecoder().decode(ProductCountsResponse.self, from: Data(json.utf8))
    }

    @Test("given a cashier's counts (no lowMargin: it's worked out from cost), should decode the rest, not fail and fall back to the 50 loaded rows")
    func cashier() throws {
        let counts = try decode(#"{"total":3356,"outOfStock":120,"lowStock":300,"synced":3351,"local":0}"#)
        #expect(counts.synced == 3351)
        #expect(counts.lowMargin == nil)
    }

    @Test("given an owner's counts, should decode lowMargin")
    func owner() throws {
        let counts = try decode(#"{"total":3356,"outOfStock":120,"lowStock":300,"lowMargin":42,"synced":3351,"local":0}"#)
        #expect(counts.lowMargin == 42)
    }

    @Test("given a server with stock alerts, should decode paused; given an old one, nil (no Pausados chip)")
    func paused() throws {
        #expect(try decode(#"{"total":3,"outOfStock":1,"lowStock":0,"paused":2,"synced":3,"local":0}"#).paused == 2)
        #expect(try decode(#"{"total":3,"outOfStock":1,"lowStock":0,"synced":3,"local":0}"#).paused == nil)
    }

    @Test("given paused products (some still with stock), In Stock should leave them out: they count only as paused")
    func inStockWithoutPaused() throws {
        #expect(try decode(#"{"total":10,"outOfStock":2,"lowStock":3,"paused":1,"synced":10,"local":0}"#).inStock == 4)
        #expect(try decode(#"{"total":10,"outOfStock":2,"lowStock":3,"synced":10,"local":0}"#).inStock == 5)
    }

    let mx = Locale(identifier: "es_MX")

    @Test("given the server's counts, should say how many of the same catalog are linked to Square, both numbers from one query")
    func summary() throws {
        let counts = try decode(#"{"total":3351,"outOfStock":120,"lowStock":300,"synced":3351,"local":0}"#)
        #expect(ProductCountsResponse.syncSummary(counts, locale: mx) == "3,351 de 3,351 sincronizados con Square")
    }

    @Test("given no server counts (the request failed), should show no summary rather than an estimate from the loaded rows")
    func noSummary() {
        #expect(ProductCountsResponse.syncSummary(nil, locale: mx) == nil)
    }
}
