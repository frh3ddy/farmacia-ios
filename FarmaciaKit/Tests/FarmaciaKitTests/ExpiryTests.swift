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
        #expect(!(Expiry.tone(daysUntil: Expiry.daysUntil(expiry, now: now, timeZone: mx)) == .critical))
    }

    @Test("given just after midnight on the expiry day, should be expired")
    func expiryDayIsExpired() {
        let now = mxTime("2026-11-15T00:10:00-06:00")
        #expect(Expiry.daysUntil(expiry, now: now, timeZone: mx) == 0)
        #expect((Expiry.tone(daysUntil: Expiry.daysUntil(expiry, now: now, timeZone: mx)) == .critical))
    }

    @Test("given 11pm two days before, should count calendar days, not 24h blocks")
    func countsCalendarDays() {
        #expect(Expiry.daysUntil(expiry, now: mxTime("2026-11-13T23:00:00-06:00"), timeZone: mx) == 2)
    }

    @Test("given a past expiry, should be negative days and expired")
    func past() {
        let now = mxTime("2026-11-20T09:00:00-06:00")
        #expect(Expiry.daysUntil(expiry, now: now, timeZone: mx) == -5)
        #expect((Expiry.tone(daysUntil: Expiry.daysUntil(expiry, now: now, timeZone: mx)) == .critical))
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

    @Test("given an expired lot on its expiry day (0 days), should say 'Venció hoy'")
    func labelExpiryDay() {
        #expect(Expiry.label(daysUntil: 0, isExpired: true, expiry: expiry) == "Venció hoy")
    }

    @Test("given days until expiry, should label relative days up to 30, then the date",
          arguments: [(-3, true, "Venció hace 3d"), (1, false, "Vence en 1d"), (30, false, "Vence en 30d")])
    func labelRelative(days: Int, expired: Bool, expected: String) {
        #expect(Expiry.label(daysUntil: days, isExpired: expired, expiry: expiry) == expected)
    }

    @Test("given 31+ days, should show the expiry date")
    func labelDate() {
        let es = Locale(identifier: "es_MX")
        #expect(Expiry.label(daysUntil: 31, isExpired: false, expiry: expiry, locale: es) == "15 nov 2026")
    }

    @Test("given a 90-day window, should include the 90th day and exclude the 91st",
          arguments: [("2026-08-17T12:00:00-06:00", true), ("2026-08-16T12:00:00-06:00", false)])
    func warningWindow(now: String, expected: Bool) {
        let days = Expiry.daysUntil(expiry, now: mxTime(now), timeZone: mx)
        #expect((Expiry.tone(daysUntil: days) == .caution) == expected)
    }
}

/// Expiry status as a tone, so screens don't pick red/orange or the 90-day cutoff themselves.
struct ExpiryToneTests {
    @Test("given a lot that expired yesterday, should be critical")
    func pastIsCritical() { #expect(Expiry.tone(daysUntil: -1) == .critical) }

    @Test("given the expiry day itself, should be critical (expired from the start of the day)")
    func todayIsCritical() { #expect(Expiry.tone(daysUntil: 0) == .critical) }

    @Test("given 90 days left, should be caution")
    func withinNinetyIsCaution() { #expect(Expiry.tone(daysUntil: 90) == .caution) }

    @Test("given 91 days left, should be neutral")
    func laterIsNeutral() { #expect(Expiry.tone(daysUntil: 91) == .neutral) }
}

extension ExpiryTests {
    @Test("given any phone language, should show the expiry day in Spanish")
    func spanishByDefault() {
        #expect(Expiry.display(ISO8601DateFormatter().date(from: "2027-01-01T18:00:00Z")!) == "1 ene 2027")
    }
}
