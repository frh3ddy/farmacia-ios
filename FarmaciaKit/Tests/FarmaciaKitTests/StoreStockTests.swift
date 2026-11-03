import Foundation
import Testing
@testable import FarmaciaKit

/// Every store's stock of one product (GET /products/:id/stock), for the
/// product detail and the receiving form.
struct StoreStockTests {
    let centro = StoreStock(locationId: "c", locationName: "Centro", quantity: 0)
    let norte = StoreStock(locationId: "n", locationName: "Norte", quantity: 7)
    let sur = StoreStock(locationId: "s", locationName: "Sur", quantity: 0)

    @Test("given the API response, should decode each store's quantity in order")
    func decodes() throws {
        let json = Data(#"{"success":true,"data":[{"locationId":"c","locationName":"Centro","quantity":0},{"locationId":"n","locationName":"Norte","quantity":7}]}"#.utf8)
        let response = try JSONDecoder().decode(StoreStockResponse.self, from: json)
        #expect(response.data == [centro, norte])
    }

    @Test("given the list, product detail should show the other stores, not this one")
    func otherStores() {
        #expect(StoreStock.others([centro, norte, sur], currentLocationId: "c") == [norte, sur])
    }

    @Test("given a product sold only here, or one that doesn't track stock, there are no other stores to show")
    func nothingElsewhere() {
        #expect(StoreStock.others([centro], currentLocationId: "c").isEmpty)
        #expect(StoreStock.others([], currentLocationId: "c").isEmpty)
    }

    @Test("given this store is at 0, a store that has it should stand out; one at 0 should not")
    func standsOutWhenOutHere() {
        #expect(norte.standsOut(hereQuantity: 0))
        #expect(!sur.standsOut(hereQuantity: 0))
    }

    @Test("given this store has stock, no store should stand out")
    func nothingStandsOutWhenInStockHere() {
        #expect(!norte.standsOut(hereQuantity: 3))
    }

    @Test("given the list, receiving should name every store, this one as Aquí first")
    func receivingSummary() {
        #expect(StoreStock.summary([centro, norte, sur], currentLocationId: "n") == "Aquí 7 · Centro 0 · Sur 0")
    }

    @Test("given an empty list (stock not tracked) or a failed fetch, receiving should show nothing")
    func noSummary() {
        #expect(StoreStock.summary([], currentLocationId: "c") == nil)
    }
}
