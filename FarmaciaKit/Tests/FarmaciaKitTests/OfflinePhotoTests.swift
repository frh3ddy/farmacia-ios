import Foundation
import Testing
@testable import FarmaciaKit

/// A product created offline keeps its photo on the device; once the queued
/// create syncs, the server's response says which product it became, and the
/// photo is uploaded for it.
struct OfflinePhotoTests {
    @Test("given a replayed product create, should read the new product's id from the response")
    func productIdFromCreate() throws {
        let response = Data(#"{"success":true,"data":{"product":{"id":"p-42","name":"Aspirina"},"squareSynced":true,"inventoryCreated":false}}"#.utf8)
        let replayed = try JSONDecoder().decode(ReplayedWrite.self, from: response)
        #expect(replayed.productId == "p-42")
    }

    @Test("given another write's response, should have no product id")
    func noProductId() throws {
        let response = Data(#"{"success":true,"data":{"adjustment":{"id":"a-1"}}}"#.utf8)
        let replayed = try JSONDecoder().decode(ReplayedWrite.self, from: response)
        #expect(replayed.productId == nil)
    }

    @Test("given a response that isn't an object, reading it should not fail the replay")
    func unexpectedShape() throws {
        let replayed = try JSONDecoder().decode(ReplayedWrite.self, from: Data("[1,2]".utf8))
        #expect(replayed.productId == nil)
    }

    @Test("given a queued create's body, should read its clientRequestId")
    func clientRequestId() {
        let body = Data(#"{"name":"Aspirina","sellingPrice":25,"clientRequestId":"req-7"}"#.utf8)
        #expect(OfflinePhoto.clientRequestId(fromBody: body) == "req-7")
        #expect(OfflinePhoto.clientRequestId(fromBody: nil) == nil)
    }

    @Test("given POST /products, should be a product create; given anything else, not")
    func productCreate() {
        #expect(OfflinePhoto.isProductCreate(method: "POST", path: "/products"))
        #expect(!OfflinePhoto.isProductCreate(method: "PATCH", path: "/products"))
        #expect(!OfflinePhoto.isProductCreate(method: "POST", path: "/inventory/adjustments"))
    }
}
