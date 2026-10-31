import Foundation
import Testing
@testable import FarmaciaKit

struct AdjustmentRequestTests {
    /// The request as JSON the API reads, so each test checks the wire format, not Swift properties.
    private func json(_ request: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func quick(quantity: Int, countedQuantity: Int? = nil, unitCost: Double? = nil) -> QuickAdjustmentRequest {
        QuickAdjustmentRequest(
            locationId: "centro",
            productId: "p1",
            quantity: quantity,
            countedQuantity: countedQuantity,
            unitCost: unitCost,
            reason: nil,
            notes: nil,
            syncToSquare: true,
            clientRequestId: "req-1"
        )
    }

    @Test("given a count correction with counted 15 and preview change 5, should send both countedQuantity and quantity")
    func countedAndChange() throws {
        let body = try json(quick(quantity: 5, countedQuantity: 15))
        #expect(body["countedQuantity"] as? Int == 15)
        // An API without countedQuantity still applies the change it knows.
        #expect(body["quantity"] as? Int == 5)
    }

    @Test("given a damage adjustment, should leave countedQuantity out of the JSON")
    func noCountedTotal() throws {
        #expect(try json(quick(quantity: 2))["countedQuantity"] == nil)
    }

    @Test("given found stock with a cost of 12.5 entered, should send unitCost")
    func sendsUnitCost() throws {
        #expect(try json(quick(quantity: 3, unitCost: 12.5))["unitCost"] as? Double == 12.5)
    }

    @Test("given a generic adjustment, should send its type and clientRequestId")
    func generic() throws {
        let body = try json(CreateAdjustmentRequest(
            locationId: "centro",
            productId: "p1",
            type: "OTHER",
            quantity: -1,
            reason: nil,
            notes: "Roto",
            unitCost: nil,
            effectiveDate: nil,
            adjustedBy: nil,
            syncToSquare: true,
            clientRequestId: "req-2"
        ))
        #expect(body["type"] as? String == "OTHER" && body["clientRequestId"] as? String == "req-2")
    }
}
