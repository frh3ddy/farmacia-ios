import Foundation

// MARK: - Expiry
//
// A lot's expiry is a calendar day. The app sends it as YYYY-MM-DD; the API
// stores it at Mexico City noon (older rows: midnight UTC). Both fall on the
// right day only when read in UTC — read in Mexico City, the legacy form lands
// at 18:00 the evening before. "Today" is the device's local day. A batch
// counts as expired from the start of its expiry day.

public enum Expiry {
    /// Calendar days from today to the expiry day (0 on the expiry day, negative after).
    public static func daysUntil(_ expiry: Date, now: Date = Date(), timeZone: TimeZone = .current) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var local = utc
        local.timeZone = timeZone

        let expiryDay = utc.dateComponents([.year, .month, .day], from: expiry)
        let today = local.dateComponents([.year, .month, .day], from: now)
        return utc.dateComponents([.day], from: today, to: expiryDay).day ?? 0
    }

    /// Short status for a lot, from the server's day count.
    public static func label(daysUntil: Int, isExpired: Bool, expiry: Date, locale: Locale = MonthYear.locale) -> String {
        if isExpired {
            return daysUntil == 0 ? "Venció hoy" : "Venció hace \(abs(daysUntil))d"
        } else if daysUntil <= 30 {
            return "Vence en \(daysUntil)d"
        } else {
            return display(expiry, locale: locale)
        }
    }

    /// The expiry day as text, e.g. "15 nov 2026".
    public static func display(_ expiry: Date, locale: Locale = MonthYear.locale) -> String {
        expiry.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: TimeZone(identifier: "UTC")!))
    }

    /// How far off the expiry is: "15 meses" past 60 days, "20 días" up to them, "vence hoy", "venció hace 3 días".
    public static func countdown(daysUntil days: Int) -> String {
        func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
        if days < 0 { return "venció hace \(plural(-days, "día", "días"))" }
        if days == 0 { return "vence hoy" }
        if days <= 60 { return plural(days, "día", "días") }
        return plural(days / 30, "mes", "meses")
    }

    /// Days of warning before a lot's expiry turns it to caution.
    public static let warningDays = 90

    /// Expired (from the start of the expiry day) → critical; within `warningDays` → caution.
    public static func tone(daysUntil: Int) -> Tone {
        if daysUntil <= 0 { return .critical }
        if daysUntil <= warningDays { return .caution }
        return .neutral
    }
}
