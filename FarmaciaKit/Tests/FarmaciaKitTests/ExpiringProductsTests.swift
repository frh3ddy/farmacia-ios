import Foundation
import Testing
@testable import FarmaciaKit

/// GET /inventory/aging/expiring as farmacia-ops sends it per role. A cashier's body
/// has no unit cost, batch value or cash at risk.
struct ExpiringProductsTests {
    func decode(_ json: String) throws -> ExpiringProductsResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // as APIClient decodes
        return try decoder.decode(ExpiringProductsResponse.self, from: Data(json.utf8))
    }

    let cashierBody = #"""
    {"products":[{"productId":"p1","productName":"Amoxicilina 500mg","sku":"750100","totalUnits":12,"batchCount":1,"expiredCount":0,
      "soonestExpiryDate":"2026-11-15T18:00:00.000Z","soonestDaysUntilExpiry":16,"severity":"HIGH",
      "batches":[{"batchId":"b1","receivingId":"r1","quantity":12,"expiryDate":"2026-11-15T18:00:00.000Z","daysUntilExpiry":16,
        "isExpired":false,"batchNumber":"L-1","supplierName":"Nadro","receivedAt":"2026-09-01T18:00:00.000Z"}]}],
     "total":1,"summary":{"totalProducts":1,"totalExpiredBatches":0,"criticalCount":0,"highCount":1}}
    """#

    let ownerBody = #"""
    {"products":[{"productId":"p1","productName":"Amoxicilina 500mg","sku":null,"totalUnits":12,"totalCashAtRisk":150,"batchCount":1,"expiredCount":0,
      "soonestExpiryDate":"2026-11-15T18:00:00.000Z","soonestDaysUntilExpiry":16,"severity":"HIGH",
      "batches":[{"batchId":"b1","receivingId":"r1","quantity":12,"unitCost":12.5,"cashValue":150,"expiryDate":"2026-11-15T18:00:00.000Z",
        "daysUntilExpiry":16,"isExpired":false,"batchNumber":null,"supplierName":null,"receivedAt":"2026-09-01T18:00:00.000Z"}]}],
     "total":1,"summary":{"totalProducts":1,"totalExpiredBatches":0,"totalCashAtRisk":150,"criticalCount":0,"highCount":1}}
    """#

    @Test("given a cashier expiring body without cost fields, should decode")
    func cashier() throws {
        let response = try decode(cashierBody)
        let product = try #require(response.products.first)
        #expect(product.totalUnits == 12)
        #expect(product.soonestDaysUntilExpiry == 16)
        #expect(product.totalCashAtRisk == nil)
        #expect(product.formattedCashAtRisk == nil)
        #expect(product.batches.first?.unitCost == nil)
        #expect(product.batches.first?.cashValue == nil)
        #expect(response.summary.totalCashAtRisk == nil)
        #expect(response.summary.highCount == 1)
    }

    @Test("given an owner body, should decode the costs as before")
    func owner() throws {
        let response = try decode(ownerBody)
        let product = try #require(response.products.first)
        #expect(product.totalCashAtRisk == 150)
        #expect(product.batches.first?.unitCost == 12.5)
        #expect(product.batches.first?.cashValue == 150)
        #expect(response.summary.totalCashAtRisk == 150)
    }
}
