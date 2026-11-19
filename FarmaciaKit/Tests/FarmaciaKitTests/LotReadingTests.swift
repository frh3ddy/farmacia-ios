import Foundation
import Testing
@testable import FarmaciaKit

struct LotReadingTests {
    let today = MonthYear(year: 2026, month: 11)
    let opened = Date(timeIntervalSince1970: 1_795_000_000)
    let jul28 = MonthYear(year: 2028, month: 7)

    private func at(_ seconds: Double) -> Date { opened.addingTimeInterval(seconds) }

    @Test("given a lote pass and then a date pass, should accept both at the date, with its time and filter")
    func acceptsOnDate() {
        var reading = LotReading(today: today, openedAt: opened)
        #expect(reading.pass(LotScan(lot: "D26U908", expiry: nil), filter: .plain, at: at(0.3)) == nil)
        #expect(reading.pass(LotScan(lot: nil, expiry: jul28), filter: .dotJoin, at: at(0.8))
                == .accept(LotScan(lot: "D26U908", expiry: jul28)))
        let row = reading.metrics(device: "iPhone14,2")
        #expect(row.msToExpiry == 800)
        #expect(row.msToLot == 300)
        #expect(row.filter == .dotJoin)
        #expect(row.passes == 2)
        #expect(row.reader == .lab)
    }

    @Test("given passes for 1 s after the accept, should count same and other dates, then say done")
    func followUp() {
        var reading = LotReading(today: today, openedAt: opened, followUp: 1)
        reading.pass(LotScan(lot: nil, expiry: jul28), filter: .plain, at: at(0.5))
        #expect(reading.pass(LotScan(lot: nil, expiry: jul28), filter: .maxComponent, at: at(0.9)) == nil)
        #expect(reading.pass(LotScan(lot: nil, expiry: MonthYear(year: 2028, month: 1)), filter: .dotJoin, at: at(1.2)) == nil)
        #expect(reading.pass(LotScan(lot: nil, expiry: nil), filter: .relief, at: at(1.4)) == nil)
        #expect(reading.pass(LotScan(lot: nil, expiry: jul28), filter: .plain, at: at(1.6)) == .done)
        #expect(reading.pass(LotScan(lot: nil, expiry: jul28), filter: .plain, at: at(1.7)) == nil)
        let row = reading.metrics(device: "iPhone14,2")
        #expect(row.sameDateReads == 1)
        #expect(row.otherDateReads == 1)
        #expect(row.passes == 1)
    }

    @Test("given no follow-up (Release), should say done right at the accept")
    func noFollowUp() {
        var reading = LotReading(today: today, openedAt: opened, followUp: 0)
        #expect(reading.pass(LotScan(lot: nil, expiry: jul28), filter: .plain, at: at(0.5)) == .accept(LotScan(lot: nil, expiry: jul28)))
        #expect(reading.pass(LotScan(lot: nil, expiry: jul28), filter: .plain, at: at(0.6)) == .done)
    }

    @Test("given the lote changing leader, should time it from when the final lote was first read")
    func lotTime() {
        var reading = LotReading(today: today, openedAt: opened)
        reading.pass(LotScan(lot: "026U908", expiry: nil), filter: .plain, at: at(0.1))
        reading.pass(LotScan(lot: "D26U908", expiry: nil), filter: .plain, at: at(0.2))
        reading.pass(LotScan(lot: "D26U908", expiry: jul28), filter: .plain, at: at(0.4))
        #expect(reading.metrics(device: "x").msToLot == 200)
        #expect(reading.metrics(device: "x").lot == "D26U908")
    }

    @Test("given a close with no date, should log a give-up row")
    func giveUp() {
        var reading = LotReading(today: today, openedAt: opened)
        reading.pass(LotScan(lot: nil, expiry: nil), filter: .plain, at: at(0.1))
        reading.pass(LotScan(lot: "A12345", expiry: nil), filter: .maxComponent, at: at(0.2))
        let row = reading.metrics(device: "x")
        #expect(row.expiry == nil)
        #expect(row.msToExpiry == nil)
        #expect(row.lot == "A12345")
        #expect(row.passes == 2)
        #expect(row.filter == nil)
    }
}
