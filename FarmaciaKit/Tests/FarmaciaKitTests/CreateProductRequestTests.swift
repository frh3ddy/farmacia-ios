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

    @Test("given a barcode, should send it as gtin; given none, should leave it out")
    func gtin() throws {
        let with = CreateProductRequest(name: "Buscapina", sku: nil, gtin: "3664798067460", description: nil, sellingPrice: 220,
                                        costPrice: nil, initialStock: nil, supplierId: nil, locationId: "centro",
                                        syncToSquare: true, clientRequestId: "id")
        #expect(try json(with)["gtin"] as? String == "3664798067460")
        #expect(try json(request())["gtin"] == nil)
    }

    private func stocked(batchNumber: String, expiry: Date?, initialStock: Int? = 5) -> CreateProductRequest {
        CreateProductRequest(name: "Óxido De Zinc", sku: nil, description: nil, sellingPrice: 45,
                             costPrice: initialStock == nil ? nil : 20, initialStock: initialStock, supplierId: nil,
                             locationId: "centro", syncToSquare: true, batchNumber: batchNumber, expiryDate: expiry,
                             clientRequestId: "id")
    }

    @Test("given initial stock with a lote and caducidad, should send batchNumber and expiryDate as the local day")
    func lotAndExpiry() throws {
        let day = try #require(LocalDay.date(from: "2027-03-01"))
        let body = try json(stocked(batchNumber: "  A23DIC  ", expiry: day))
        #expect(body["batchNumber"] as? String == "A23DIC")
        #expect(body["expiryDate"] as? String == "2027-03-01")
    }

    @Test("given an empty lote and no caducidad, should leave both out")
    func noLot() throws {
        let body = try json(stocked(batchNumber: " ", expiry: nil))
        #expect(body["batchNumber"] == nil && body["expiryDate"] == nil)
    }

    @Test("given no initial stock, should leave the lote and caducidad out: there's no batch to put them on")
    func lotNeedsStock() throws {
        let body = try json(stocked(batchNumber: "A23DIC", expiry: LocalDay.date(from: "2027-03-01"), initialStock: nil))
        #expect(body["batchNumber"] == nil && body["expiryDate"] == nil)
    }

    @Test("given a lote longer than the server's 100-character cap, should send its first 100, as the server keeps")
    func lotCap() throws {
        let body = try json(stocked(batchNumber: String(repeating: "A", count: 130), expiry: nil))
        #expect((body["batchNumber"] as? String)?.count == 100)
    }
}
