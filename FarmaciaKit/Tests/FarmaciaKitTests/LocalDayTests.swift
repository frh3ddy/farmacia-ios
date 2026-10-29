import Foundation
import Testing
@testable import FarmaciaKit

struct LocalDayTests {
    let mexicoCity = TimeZone(identifier: "America/Mexico_City")!

    @Test("given 11pm local time, should send the local calendar day, not the GMT one")
    func lateEveningStaysOnLocalDay() {
        // 2026-03-10 23:30 in Mexico City is already 2026-03-11 in GMT (regression 1d7d355).
        let date = Date(timeIntervalSince1970: 1_773_207_000)
        #expect(LocalDay.string(from: date, timeZone: mexicoCity) == "2026-03-10")
    }

    @Test("given a YYYY-MM-DD string, should round-trip to the same string",
          arguments: ["2026-01-01", "2026-04-05", "2026-11-01", "2026-12-31"])
    func roundTrips(day: String) throws {
        let date = try #require(LocalDay.date(from: day, timeZone: mexicoCity))
        #expect(LocalDay.string(from: date, timeZone: mexicoCity) == day)
    }

    @Test("given garbage, should return nil")
    func rejectsGarbage() {
        #expect(LocalDay.date(from: "10/03/2026") == nil)
    }
}
