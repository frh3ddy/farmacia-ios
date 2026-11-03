import Foundation
import Testing
@testable import FarmaciaKit

struct LotSummaryTests {
    func lot(age: Int, expiry: Date? = nil) -> BatchValuation {
        BatchValuation(batchId: UUID().uuidString, quantity: 1, receivedAt: Date(), age: age, expiryDate: expiry)
    }

    @Test func countsByAgeUsingBatchAgeCutoffs() {
        let summary = LotSummary(lots: [lot(age: 29), lot(age: 30), lot(age: 90)])
        #expect(summary.fresh == 1)
        #expect(summary.moderate == 1)
        #expect(summary.old == 1)
    }

    @Test func countsExpiredAndExpiringSoon() {
        let summary = LotSummary(lots: [
            lot(age: 1, expiry: Date().addingTimeInterval(-10 * 86_400)),
            lot(age: 1, expiry: Date().addingTimeInterval(30 * 86_400)),
            lot(age: 1, expiry: Date().addingTimeInterval(400 * 86_400)),
            lot(age: 1),
        ])
        #expect(summary.expired == 1)
        #expect(summary.expiringSoon == 1)
    }
}
