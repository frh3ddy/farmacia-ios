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
}
