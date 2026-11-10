import Foundation

// MARK: - Month Year
//
// A lot's expiry as printed on the box: "CAD 03/2027". Saved as the first day
// of that month, so the store has the whole month to sell it at a discount
// (tasks/lot-expiry-capture-epic.md).

public struct MonthYear: Equatable, Hashable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// The month `date` falls in, read in `timeZone` (UTC for an expiry from the API, see `Expiry`).
    public init(date: Date, timeZone: TimeZone = .current) {
        let parts = Self.calendar(timeZone).dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 1)
    }

    /// The 1st of the month at local midnight; the form sends it with `LocalDay.string`.
    public func firstDay(timeZone: TimeZone = .current) -> Date {
        Self.calendar(timeZone).date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    /// "mar 2027". Spanish whatever the phone's language, like the rest of the app.
    public func display(locale: Locale = MonthYear.locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = TimeZone(identifier: "UTC")
        f.setLocalizedDateFormatFromTemplate("MMMyyyy")
        return f.string(from: firstDay(timeZone: f.timeZone)).replacingOccurrences(of: ".", with: "").lowercased()
    }

    public static let locale = Locale(identifier: "es_MX")

    /// "Enero" … "Diciembre", for a month wheel.
    public static let monthNames: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.standaloneMonthSymbols.map(\.capitalized)
    }()

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }
}

extension MonthYear {
    /// The 1st of this month has come, so the lot saves as already expired
    /// (`Expiry` counts it expired from that day). Doesn't block saving.
    public func expiredWarning(today: MonthYear) -> String? {
        today.isBefore(self) ? nil : "Se guarda como vencido desde el 1.º de mes"
    }
}

extension MonthYear {
    /// What the wheels start on: the saved expiry, or a year out (the usual shelf life).
    public static func openingValue(current: MonthYear?, today: MonthYear) -> MonthYear {
        current ?? MonthYear(year: today.year + 1, month: today.month)
    }

    /// When the wheels' sheet closes: Listo or Quitar (`confirmed`) keep what's shown;
    /// swiping it away is a cancel, so the expiry goes back to what it was before
    /// opening, including empty, so a year-out start nobody chose isn't saved.
    public static func closingValue(before: MonthYear?, current: MonthYear?, confirmed: Bool) -> MonthYear? {
        confirmed ? current : before
    }
}
