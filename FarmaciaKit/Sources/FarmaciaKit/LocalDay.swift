import Foundation

// MARK: - Local Day
//
// The API takes and returns date-only fields as `YYYY-MM-DD` meaning the
// business-local calendar day. Formatting must use the device timezone (not
// GMT — see ISO8601DateFormatter's default) and a fixed Gregorian/POSIX
// locale so the user's calendar setting can't change the digits.

public enum LocalDay {
    public static func string(from date: Date, timeZone: TimeZone = .current) -> String {
        formatter(timeZone).string(from: date)
    }

    public static func date(from string: String, timeZone: TimeZone = .current) -> Date? {
        formatter(timeZone).date(from: string)
    }

    private static func formatter(_ timeZone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = timeZone
        return f
    }
}
