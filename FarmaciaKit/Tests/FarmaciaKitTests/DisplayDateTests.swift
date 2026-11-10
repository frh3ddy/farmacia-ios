import Foundation
import Testing
@testable import FarmaciaKit

/// One date format and one timestamp format for detail screens (es_MX, the device's zone).
struct DisplayDateTests {
    let mx = TimeZone(identifier: "America/Mexico_City")!

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = mx
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("given 2026-11-02 02:57 local, should format the timestamp \"2 nov · 2:57 a.m.\"")
    func timestamp() {
        #expect(DisplayDate.timestamp(date(2026, 11, 2, 2, 57), timeZone: mx) == "2 nov · 2:57 a.m.")
    }

    @Test("given 2026-09-24 at 11pm local, should show the local day \"24 sep 2026\"")
    func day() {
        #expect(DisplayDate.day(date(2026, 9, 24, 23), timeZone: mx) == "24 sep 2026")
    }

    @Test("given a date in the current year, the short day should drop the year")
    func shortDay() {
        let now = date(2026, 11, 10)
        #expect(DisplayDate.shortDay(date(2026, 11, 1), now: now, timeZone: mx) == "1 nov")
        #expect(DisplayDate.shortDay(date(2025, 11, 1), now: now, timeZone: mx) == "1 nov 2025")
    }

    @Test("given a sync 2 days ago, should say \"hace 2 días\"",
          arguments: [(0, "hoy"), (1, "ayer"), (2, "hace 2 días"), (40, "hace 40 días")])
    func relative(daysAgo: Int, expected: String) {
        let now = date(2026, 11, 10, 9)
        let then = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        #expect(DisplayDate.relative(then, now: now, timeZone: mx) == expected)
    }
}
