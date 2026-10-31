import Foundation
import Testing
@testable import FarmaciaKit

struct APIResponseTests {
    struct Item: Decodable, Equatable { let id: String }

    func decode(_ json: String) throws -> APIResponse<Item> {
        try JSONDecoder().decode(APIResponse<Item>.self, from: Data(json.utf8))
    }

    @Test("given a success response with no data, should throw noData instead of passing silently")
    func missingDataThrows() throws {
        let response = try decode(#"{"success":true,"message":"ok"}"#)
        #expect(throws: NetworkError.self) { try response.requireData() }
    }

    @Test("given a success response with data, should return it")
    func presentDataReturns() throws {
        let response = try decode(#"{"success":true,"data":{"id":"p1"}}"#)
        #expect(try response.requireData() == Item(id: "p1"))
    }
}
