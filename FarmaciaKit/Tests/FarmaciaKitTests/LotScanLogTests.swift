import Foundation
import Testing
@testable import FarmaciaKit

struct LotScanLogTests {
    let date = Date(timeIntervalSince1970: 1_795_000_000)
    let jul28 = MonthYear(year: 2028, month: 7)

    private func row(lot: String?, expiry: MonthYear?) -> LotScanMetrics {
        LotScanMetrics(date: date, device: "x", reader: .lab, lot: lot, expiry: expiry,
                       msToExpiry: nil, msToLot: nil, passes: 1, filter: nil, edited: nil)
    }

    @Test("given a read and then a save, should mark that read's row")
    func marksRead() {
        var log = LotScanLog()
        log.log(row(lot: "A1", expiry: jul28))
        log.saved(lot: "A2", expiry: jul28)
        #expect(log.rows[0].edited == true)
    }

    @Test("given read A, then a give-up for B, then a hand-typed save, should not mark A (review dev-f8)")
    func giveUpClearsFill() {
        var log = LotScanLog()
        log.log(row(lot: "A1", expiry: jul28))
        log.log(row(lot: nil, expiry: nil))
        log.saved(lot: "B9", expiry: MonthYear(year: 2029, month: 1))
        #expect(log.rows[0].edited == nil)
        #expect(log.rows[1].edited == nil)
    }

    @Test("given a read whose form closed without saving, a later save should not mark it")
    func formClosedClearsFill() {
        var log = LotScanLog()
        log.log(row(lot: "A1", expiry: jul28))
        log.formClosed()
        log.saved(lot: "B9", expiry: jul28)
        #expect(log.rows[0].edited == nil)
    }

    @Test("given saved rows, should decode back to the same log")
    func roundTrips() throws {
        var log = LotScanLog()
        log.log(row(lot: "A1", expiry: jul28))
        #expect(try JSONDecoder().decode(LotScanLog.self, from: JSONEncoder().encode(log)).rows == log.rows)
    }
}
