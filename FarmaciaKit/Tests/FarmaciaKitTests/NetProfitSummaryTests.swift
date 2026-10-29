import Foundation
import Testing
@testable import FarmaciaKit

struct NetProfitSummaryTests {
    func decode(_ json: String) throws -> NetProfitSummary {
        try JSONDecoder().decode(NetProfitSummary.self, from: Data(json.utf8))
    }

    @Test("given a dashboard body without yastasServiceRevenue (older server), should still decode")
    func olderServer() throws {
        let summary = try decode(#"{"amount":"18000","marginPercent":"18.00"}"#)
        #expect(summary.amount == "18000")
        #expect(summary.yastasServiceRevenue == nil)
    }

    @Test("given a dashboard body with yastasServiceRevenue, should read it")
    func newServer() throws {
        let summary = try decode(#"{"amount":"21000","marginPercent":"20.39","yastasServiceRevenue":"3000"}"#)
        #expect(summary.yastasServiceRevenue == "3000")
    }
}
