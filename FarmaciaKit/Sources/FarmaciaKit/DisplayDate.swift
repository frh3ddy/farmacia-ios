import Foundation

// MARK: - Display Date
//
// One day format and one timestamp format for what screens show (es_MX, the
// device's zone): "24 sep 2026", "2 nov · 2:57 a.m.", "hace 2 días". Lot expiry
// is a calendar day with its own rules — use `Expiry.display` for that.
public enum DisplayDate {
    public static let locale = Locale(identifier: "es_MX")

    /// "24 sep 2026".
    public static func day(_ date: Date, timeZone: TimeZone = .current) -> String {
        format(date, "d MMM yyyy", timeZone)
    }

    /// "1 nov" this year, "1 nov 2025" otherwise.
    public static func shortDay(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        let calendar = calendar(timeZone)
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return sameYear ? format(date, "d MMM", timeZone) : day(date, timeZone: timeZone)
    }

    /// "2 nov · 2:57 a.m.".
    public static func timestamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        "\(format(date, "d MMM", timeZone)) · \(format(date, "h:mm a", timeZone))"
    }

    /// "hoy", "ayer", "hace 2 días" — by calendar day.
    public static func relative(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current) -> String {
        let calendar = calendar(timeZone)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "hoy"
        case 1: return "ayer"
        default: return "hace \(days) días"
        }
    }

    private static func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func format(_ date: Date, _ pattern: String, _ timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        // es_MX's ICU writes "am"; Mexican usage (and the rest of the app) is "a.m.".
        formatter.amSymbol = "a.m."
        formatter.pmSymbol = "p.m."
        return formatter.string(from: date)
    }
}
