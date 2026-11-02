import Foundation

// MARK: - Amount Text
//
// Amount fields (price, cost, quantity) keep the user's text and read the
// number on every keystroke, instead of `TextField(value:format:)`, which only
// writes back when editing ends — and the number pad has no return key, so a
// form's Crear stayed disabled until the user left the field.

public enum AmountText {
    /// The number in `text`, or nil when it isn't one (yet). Accepts "." or ","
    /// as the decimal separator; with both, "," is a thousands separator.
    public static func parse(_ text: String) -> Double? {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.contains(".") {
            s = s.replacingOccurrences(of: ",", with: "")
        } else {
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        // Digits and one separator only — Double() would also take "inf", "1e5".
        guard s.contains(where: \.isNumber), s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }) else {
            return nil
        }
        return Double(s)
    }

    /// How a value set from elsewhere (e.g. a prefilled cost) shows in the field:
    /// no trailing zeros, at most two decimals, no grouping.
    public static func string(from value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(
            .number
                .precision(.fractionLength(0...2))
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}
