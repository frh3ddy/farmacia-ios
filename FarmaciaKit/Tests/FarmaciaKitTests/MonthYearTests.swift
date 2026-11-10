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

struct MonthYearOpeningTests {
    @Test("given no expiry yet and today March 2026, should open on March 2027")
    func emptyOpensAYearOut() {
        #expect(MonthYear.openingValue(current: nil, today: MonthYear(year: 2026, month: 3))
                == MonthYear(year: 2027, month: 3))
    }

    @Test("given an expiry of May 2028, should open on it")
    func setOpensOnItself() {
        #expect(MonthYear.openingValue(current: MonthYear(year: 2028, month: 5), today: MonthYear(year: 2026, month: 3))
                == MonthYear(year: 2028, month: 5))
    }
}

struct MonthYearClosingTests {
    let may2028 = MonthYear(year: 2028, month: 5)
    let june2028 = MonthYear(year: 2028, month: 6)

    @Test("given an empty expiry opened and swiped away without Listo, should go back to empty")
    func swipedAwayEmpty() {
        #expect(MonthYear.closingValue(before: nil, current: june2028, confirmed: false) == nil)
    }

    @Test("given May 2028 changed to June and swiped away without Listo, should keep May")
    func swipedAwayKeepsOld() {
        #expect(MonthYear.closingValue(before: may2028, current: june2028, confirmed: false) == may2028)
    }

    @Test("given June picked and Listo tapped, should keep June")
    func listoKeeps() {
        #expect(MonthYear.closingValue(before: may2028, current: june2028, confirmed: true) == june2028)
    }

    @Test("given Quitar caducidad tapped, should stay empty")
    func quitarClears() {
        #expect(MonthYear.closingValue(before: may2028, current: nil, confirmed: true) == nil)
    }
}
