import Foundation

// MARK: - Report Format
//
// The API sends money and percentages as decimal strings. These format them
// for display. Currency defaults to es_MX so an English-locale device still
// shows "$1,234.50" for pesos instead of "MX$1,234.50".

public enum ReportFormat {
    public static func currency(_ value: String, locale: Locale = Locale(identifier: "es_MX")) -> String {
        guard let doubleValue = Double(value) else { return "$\(value)" }
        return currency(doubleValue, locale: locale)
    }

    public static func currency(_ value: Double, locale: Locale = Locale(identifier: "es_MX")) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = "MXN"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    public static func percent(_ value: String) -> String {
        guard let doubleValue = Double(value) else { return "\(value)%" }
        return String(format: "%.1f%%", doubleValue)
    }

    /// Gain or zero (shown green) vs. loss (shown red). Unparseable counts as zero.
    public static func isNonNegative(_ amount: String) -> Bool {
        (Double(amount) ?? 0) >= 0
    }
}
