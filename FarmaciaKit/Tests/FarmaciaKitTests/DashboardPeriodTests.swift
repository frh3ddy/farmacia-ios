import Foundation
import Testing
@testable import FarmaciaKit

struct DashboardPeriodTests {
    let mx = TimeZone(identifier: "America/Mexico_City")!

    /// A Mexico City calendar; `sundayFirst` mimics an es_MX device (weeks start Sunday).
    func calendar(sundayFirst: Bool = false) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = mx
        c.locale = Locale(identifier: "es_MX")
        c.firstWeekday = sundayFirst ? 1 : 2
        return c
    }

    /// Noon on that day in Mexico City.
    func day(_ s: String) -> Date { LocalDay.date(from: s, timeZone: mx)!.addingTimeInterval(12 * 3600) }

    func days(_ period: DashboardPeriod, on today: String, sundayFirst: Bool = false) -> [String] {
        let range = period.days(now: day(today), calendar: calendar(sundayFirst: sundayFirst))
        return [range.start, range.end]
    }

    @Test("given Thursday Oct 29 2026, this week should be 2026-10-26 to 2026-10-29")
    func thisWeek() {
        #expect(days(.thisWeek, on: "2026-10-29") == ["2026-10-26", "2026-10-29"])
    }

    @Test("given Sunday Nov 1 on an es_MX calendar (Sunday-first), this week should still start Monday Oct 26")
    func mondayStartRegardlessOfLocale() {
        #expect(days(.thisWeek, on: "2026-11-01", sundayFirst: true) == ["2026-10-26", "2026-11-01"])
    }

    @Test("given a Monday, this week should be that day only and last week the previous Monday to Sunday")
    func onMonday() {
        #expect(days(.thisWeek, on: "2026-10-26") == ["2026-10-26", "2026-10-26"])
        #expect(days(.lastWeek, on: "2026-10-26") == ["2026-10-19", "2026-10-25"])
    }

    @Test("given Oct 29, last week should be Oct 19–25")
    func lastWeek() {
        #expect(days(.lastWeek, on: "2026-10-29", sundayFirst: true) == ["2026-10-19", "2026-10-25"])
    }

    @Test("given Oct 29, this month should be Oct 1–29 and last month Sep 1–30")
    func months() {
        #expect(days(.thisMonth, on: "2026-10-29") == ["2026-10-01", "2026-10-29"])
        #expect(days(.lastMonth, on: "2026-10-29") == ["2026-09-01", "2026-09-30"])
    }

    @Test("given the end of March, last month should be all of February",
          arguments: [("2027-03-31", "2027-02-28"), ("2028-03-15", "2028-02-29")])
    func february(today: String, lastDay: String) {
        #expect(days(.lastMonth, on: today) == [String(lastDay.prefix(8)) + "01", lastDay])
    }

    @Test("given Jan 1, yesterday should be Dec 31 of the year before")
    func yesterday() {
        #expect(days(.yesterday, on: "2027-01-01") == ["2026-12-31", "2026-12-31"])
    }

    @Test("given 11:30pm in Mexico City (already tomorrow in UTC), today should be the local day")
    func lateNight() {
        let lateNight = day("2026-10-29").addingTimeInterval(11.5 * 3600) // 23:30 local = 05:30Z next day
        let range = DashboardPeriod.today.days(now: lateNight, calendar: calendar())
        #expect([range.start, range.end] == ["2026-10-29", "2026-10-29"])
    }

    @Test("this year should be Jan 1 to today")
    func thisYear() {
        #expect(days(.thisYear, on: "2026-10-29") == ["2026-01-01", "2026-10-29"])
    }

    @Test("given the picker, should list the periods in order with This Month as default")
    func options() {
        #expect(DashboardPeriod.allCases.map(\.displayName) == ["Hoy", "Ayer", "Esta Semana", "Semana Pasada", "Este Mes", "Mes Pasado", "Este Año"])
        #expect(DashboardPeriod.default == .thisMonth)
    }
}
