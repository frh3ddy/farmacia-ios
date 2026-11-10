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

    /// `currency` split for the big-number style: "$" + "220" + ".00", cents set smaller.
    public struct CurrencyParts: Equatable, Sendable {
        public let symbol: String
        public let whole: String
        public let fraction: String
    }

    public static func currencyParts(_ value: Double, locale: Locale = Locale(identifier: "es_MX")) -> CurrencyParts {
        let text = currency(value, locale: locale)
        let digitsStart = text.firstIndex(where: \.isNumber) ?? text.endIndex
        let decimal = locale.decimalSeparator ?? "."
        let number = text[digitsStart...]
        let fractionStart = number.range(of: decimal, options: .backwards)?.lowerBound ?? number.endIndex
        return CurrencyParts(
            symbol: String(text[..<digitsStart]),
            whole: String(number[..<fractionStart]),
            fraction: String(number[fractionStart...])
        )
    }

    public static func percent(_ value: String) -> String {
        guard let doubleValue = Double(value) else { return "\(value)%" }
        return String(format: "%.1f%%", doubleValue)
    }

    /// Gain or zero → positive, loss → critical.
    public static func tone(_ amount: String) -> Tone {
        isNonNegative(amount) ? .positive : .critical
    }

    /// Gain or zero (shown green) vs. loss (shown red). Unparseable counts as zero.
    public static func isNonNegative(_ amount: String) -> Bool {
        (Double(amount) ?? 0) >= 0
    }
}
