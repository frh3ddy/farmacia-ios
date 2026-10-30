import Foundation
import Testing
@testable import FarmaciaKit

struct CreateProductRequestTests {
    /// The request as JSON the API reads, so each test checks the wire format, not Swift properties.
    private func json(_ request: CreateProductRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func request(soldAtAllLocations: Bool = true, clientRequestId: String = "2E6B1C1E-7F7B-4D3A-9C55-6C1F6A7E0B01") -> CreateProductRequest {
        CreateProductRequest(
            name: "Dinosaurio",
            sku: nil,
            description: nil,
            sellingPrice: 199,
            costPrice: nil,
            initialStock: nil,
            supplierId: nil,
            locationId: "centro",
            syncToSquare: true,
            soldAtAllLocations: soldAtAllLocations,
            clientRequestId: clientRequestId
        )
    }

    @Test("given a product sold only at this store, should send soldAtAllLocations false", arguments: [true, false])
    func soldAt(everyStore: Bool) throws {
        #expect(try json(request(soldAtAllLocations: everyStore))["soldAtAllLocations"] as? Bool == everyStore)
    }

    @Test("given a create, should send its clientRequestId so the API can recognise a retry")
    func clientRequestId() throws {
        #expect(try json(request())["clientRequestId"] as? String == "2E6B1C1E-7F7B-4D3A-9C55-6C1F6A7E0B01")
    }

    @Test("given no stock or cost, should leave those fields out rather than send null")
    func omitsUnset() throws {
        let body = try json(request())
        #expect(body["initialStock"] == nil && body["costPrice"] == nil && body["supplierId"] == nil)
    }
}
