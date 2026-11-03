import Foundation
import Testing
@testable import FarmaciaKit

/// A lot from GET /inventory/reports/valuation (`byProduct[].batches[]`).
struct BatchValuationTests {
    @Test func decodesExpiryAndTone() throws {
        let json = #"""
        {"batchId":"b1","quantity":12,"unitCost":"12.50","value":"150.00",
         "receivedAt":"2026-01-10T18:00:00.000Z","age":297,"source":"PURCHASE",
         "batchNumber":"L-77","expiryDate":"2020-06-01T18:00:00.000Z","manufacturingDate":null,
         "invoiceNumber":null,"supplierId":"s1","supplierName":"Nadro"}
        """#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // as APIClient decodes
        let lot = try decoder.decode(BatchValuation.self, from: Data(json.utf8))

        #expect(lot.id == "b1")
        #expect(lot.batchNumber == "L-77")
        #expect(lot.expiryTone == .critical)
        #expect(lot.sourceLabel == "Compra")
    }

    // FIFO sells the oldest lot first.
    let jan = BatchValuation(batchId: "jan", quantity: 0, receivedAt: Date(timeIntervalSince1970: 1_767_225_600))
    let feb = BatchValuation(batchId: "feb", quantity: 4, receivedAt: Date(timeIntervalSince1970: 1_769_904_000))
    let mar = BatchValuation(batchId: "mar", quantity: 6, receivedAt: Date(timeIntervalSince1970: 1_772_323_200))

    @Test func fifoOrderPutsOldestFirst() {
        #expect(BatchValuation.fifoOrder([mar, jan, feb]).map(\.id) == ["jan", "feb", "mar"])
    }

    @Test func nextOutSkipsEmptyLots() {
        #expect(BatchValuation.nextOut([mar, jan, feb])?.id == "feb")
    }

    @Test func nextOutNilWhenAllEmpty() {
        #expect(BatchValuation.nextOut([jan]) == nil)
    }
}
