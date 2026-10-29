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

    /// The expiry day as text, e.g. "15 nov 2026".
    public static func display(_ expiry: Date, locale: Locale = .current) -> String {
        expiry.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, timeZone: TimeZone(identifier: "UTC")!))
    }

    public static func isExpired(_ expiry: Date, now: Date = Date(), timeZone: TimeZone = .current) -> Bool {
        daysUntil(expiry, now: now, timeZone: timeZone) <= 0
    }

    public static func expiresWithin(_ expiry: Date, days: Int, now: Date = Date(), timeZone: TimeZone = .current) -> Bool {
        daysUntil(expiry, now: now, timeZone: timeZone) <= days
    }
}
