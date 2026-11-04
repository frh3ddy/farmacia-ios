import Foundation
import Testing
@testable import FarmaciaKit

struct ReceiveInventoryRequestTests {
    /// The request as JSON the API reads, so each test checks the wire format, not Swift properties.
    private func json(_ request: ReceiveInventoryRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func request(
        invoiceNumber: String = "F-100",
        batchNumber: String = "L-7",
        notes: String = "",
        expiryDate: Date? = nil,
        sellingPrice: Double? = nil,
        priceAtAllLocations: Bool = false,
        clientRequestId: String = "req-1"
    ) -> ReceiveInventoryRequest {
        ReceiveInventoryRequest(
            locationId: "centro",
            productId: "p1",
            quantity: 10,
            unitCost: 12.5,
            supplierId: nil,
            invoiceNumber: invoiceNumber,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            notes: notes,
            sellingPrice: sellingPrice,
            priceAtAllLocations: priceAtAllLocations,
            clientRequestId: clientRequestId
        )
    }

    @Test("given the same draft built twice with one clientRequestId, should produce equal requests")
    func retryIsTheSameRequest() {
        #expect(request() == request())
    }

    @Test("given an empty invoice, batch and notes, should leave them out of the JSON")
    func blanksAbsent() throws {
        let body = try json(request(invoiceNumber: "", batchNumber: "", notes: ""))
        #expect(body["invoiceNumber"] == nil && body["batchNumber"] == nil && body["notes"] == nil)
    }

    @Test("given an expiry date, should send it as the local calendar day")
    func expiryAsLocalDay() throws {
        let noon = try #require(LocalDay.date(from: "2027-03-14"))
        #expect(try json(request(expiryDate: noon))["expiryDate"] as? String == "2027-03-14")
    }

    @Test("given no new selling price, should send neither the price nor whether to sync it")
    func noPrice() throws {
        let body = try json(request())
        #expect(body["sellingPrice"] == nil && body["syncPriceToSquare"] == nil)
    }

    @Test("given a new selling price, should ask the API to sync it to Square")
    func withPrice() throws {
        let body = try json(request(sellingPrice: 45))
        #expect(body["sellingPrice"] as? Double == 45 && body["syncPriceToSquare"] as? Bool == true)
    }

    @Test("given a new price for every store, should ask the API to apply it at every store")
    func priceEverywhere() throws {
        #expect(try json(request(sellingPrice: 45, priceAtAllLocations: true))["applyPriceToAllLocations"] as? Bool == true)
    }

    @Test("given every store but no new price, or this store only, should leave the flag out",
          arguments: [(nil, true), (45.0, false)] as [(Double?, Bool)])
    func flagAbsent(price: Double?, everywhere: Bool) throws {
        #expect(try json(request(sellingPrice: price, priceAtAllLocations: everywhere))["applyPriceToAllLocations"] == nil)
    }
}
