import Foundation
import Testing
@testable import FarmaciaKit

struct UpdatePriceRequestTests {
    func json(_ request: UpdatePriceRequest) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
    }

    @Test("given Square off and all stores on, should still send applyToAllLocations")
    func allStoresWithoutSquare() throws {
        let body = try json(UpdatePriceRequest(sellingPrice: 45, locationId: "loc-1", syncToSquare: false, applyToAllLocations: true))
        #expect(body["applyToAllLocations"] as? Bool == true)
        #expect(body["syncToSquare"] as? Bool == false)
    }

    @Test("given one store, should not send applyToAllLocations (a manager's is refused)")
    func oneStore() throws {
        let body = try json(UpdatePriceRequest(sellingPrice: 45, locationId: "loc-1", syncToSquare: true, applyToAllLocations: false))
        #expect(body["applyToAllLocations"] == nil)
        #expect(body["sellingPrice"] as? Double == 45)
        #expect(body["locationId"] as? String == "loc-1")
    }
}
