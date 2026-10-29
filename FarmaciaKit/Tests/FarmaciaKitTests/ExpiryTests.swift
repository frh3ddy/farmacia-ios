import Foundation
import Testing
@testable import FarmaciaKit

struct ExpiryTests {
    let mx = TimeZone(identifier: "America/Mexico_City")!
    // Lot entered as expiring 2026-11-15 → API stores and returns midnight UTC.
    let expiry = ISO8601DateFormatter().date(from: "2026-11-15T00:00:00Z")!

    func mxTime(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = mx
        return f.date(from: s)!
    }

    @Test("given 6:30pm the evening before the expiry day, should not be expired yet")
    func eveningBeforeIsNotExpired() {
        let now = mxTime("2026-11-14T18:30:00-06:00")
        #expect(Expiry.daysUntil(expiry, now: now, timeZone: mx) == 1)
        #expect(!Expiry.isExpired(expiry, now: now, timeZone: mx))
    }

    @Test("given just after midnight on the expiry day, should be expired")
    func expiryDayIsExpired() {
        let now = mxTime("2026-11-15T00:10:00-06:00")
        #expect(Expiry.daysUntil(expiry, now: now, timeZone: mx) == 0)
        #expect(Expiry.isExpired(expiry, now: now, timeZone: mx))
    }

    @Test("given 11pm two days before, should count calendar days, not 24h blocks")
    func countsCalendarDays() {
        #expect(Expiry.daysUntil(expiry, now: mxTime("2026-11-13T23:00:00-06:00"), timeZone: mx) == 2)
    }

    @Test("given a past expiry, should be negative days and expired")
    func past() {
        let now = mxTime("2026-11-20T09:00:00-06:00")
        #expect(Expiry.daysUntil(expiry, now: now, timeZone: mx) == -5)
        #expect(Expiry.isExpired(expiry, now: now, timeZone: mx))
    }

    @Test("given either stored form of a Nov 15 expiry, should land on the same day",
          arguments: ["2026-11-15T00:00:00Z", "2026-11-15T18:00:00Z"]) // legacy UTC midnight; Mexico City noon (parseBusinessDate)
    func bothStoredForms(stored: String) {
        let stored = ISO8601DateFormatter().date(from: stored)!
        let now = mxTime("2026-11-14T20:00:00-06:00")
        #expect(Expiry.daysUntil(stored, now: now, timeZone: mx) == 1)
        #expect(Expiry.display(stored, locale: Locale(identifier: "es_MX")) == "15 nov 2026")
    }

    @Test("given a Nov 15 expiry on a Mexico City device, should display Nov 15, not Nov 14")
    func displaysStoredDay() {
        #expect(Expiry.display(expiry, locale: Locale(identifier: "es_MX")) == "15 nov 2026")
    }

    @Test("given a 90-day window, should include the 90th day and exclude the 91st",
          arguments: [("2026-08-17T12:00:00-06:00", true), ("2026-08-16T12:00:00-06:00", false)])
    func expiresWithin(now: String, expected: Bool) {
        #expect(Expiry.expiresWithin(expiry, days: 90, now: mxTime(now), timeZone: mx) == expected)
    }
}
