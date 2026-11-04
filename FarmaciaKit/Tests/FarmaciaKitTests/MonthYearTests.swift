import Foundation
import Testing
@testable import FarmaciaKit

struct MonthYearTests {
    let mx = TimeZone(identifier: "America/Mexico_City")!
    let utc = TimeZone(identifier: "UTC")!

    @Test("given March 2027, should save 2027-03-01")
    func savesFirstDay() {
        let march = MonthYear(year: 2027, month: 3)
        #expect(LocalDay.string(from: march.firstDay(timeZone: mx), timeZone: mx) == "2027-03-01")
    }

    @Test("given a lot's expiry date from the API, should read back the same month",
          arguments: ["2027-03-01T00:00:00Z", "2027-03-31T18:00:00Z"])
    func readsMonthBack(iso: String) throws {
        let date = try #require(ISO8601DateFormatter().date(from: iso))
        #expect(MonthYear(date: date, timeZone: utc) == MonthYear(year: 2027, month: 3))
    }

    @Test("given any phone language, should name months in Spanish")
    func spanishMonths() {
        #expect(MonthYear(year: 2027, month: 1).display() == "ene 2027")
        #expect(MonthYear.monthNames.first == "Enero")
    }

    @Test("given March 2027, should display a short month and the year")
    func display() {
        #expect(MonthYear(year: 2027, month: 3).display(locale: Locale(identifier: "es_MX")) == "mar 2027")
    }
}

extension MonthYearTests {
    @Test("given an expiry month that started on or before today, should warn it saves as expired",
          arguments: [MonthYear(year: 2026, month: 11), MonthYear(year: 2026, month: 2)])
    func pastMonthWarns(month: MonthYear) {
        #expect(month.expiredWarning(today: MonthYear(year: 2026, month: 11)) == "Se guarda como vencido desde el 1.º de mes")
    }

    @Test("given next month, should not warn")
    func nextMonthIsFine() {
        #expect(MonthYear(year: 2026, month: 12).expiredWarning(today: MonthYear(year: 2026, month: 11)) == nil)
    }
}
