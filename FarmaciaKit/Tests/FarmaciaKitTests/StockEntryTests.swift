import Testing
@testable import FarmaciaKit

struct StockEntryTests {
    @Test("given a product sold only at another store, should not allow adding stock here")
    func otherStore() {
        #expect(!StockEntry.canAdd(soldOnlyAtLocationId: "centro", currentLocationId: "norte"))
    }

    @Test("given a product sold everywhere or only here, should allow adding stock",
          arguments: [(nil, "norte"), ("norte", "norte")] as [(String?, String?)])
    func allowed(soldOnlyAt: String?, here: String?) {
        #expect(StockEntry.canAdd(soldOnlyAtLocationId: soldOnlyAt, currentLocationId: here))
    }
}
