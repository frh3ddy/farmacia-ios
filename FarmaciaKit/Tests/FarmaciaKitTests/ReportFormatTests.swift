import Foundation
import Testing
@testable import FarmaciaKit

struct ReportFormatTests {
    let mx = Locale(identifier: "es_MX")

    @Test("given an API money string, should format as MXN currency",
          arguments: [("1234.5", "$1,234.50"), ("0", "$0.00"), ("-89.999", "-$90.00")])
    func currency(value: String, expected: String) {
        #expect(ReportFormat.currency(value, locale: mx) == expected)
    }

    @Test("given a non-numeric money string, should show it raw with a $ prefix")
    func currencyGarbage() {
        #expect(ReportFormat.currency("N/A", locale: mx) == "$N/A")
    }

    @Test("given an API percent string, should show one decimal",
          arguments: [("33.333", "33.3%"), ("-5", "-5.0%"), ("abc", "abc%")])
    func percent(value: String, expected: String) {
        #expect(ReportFormat.percent(value) == expected)
    }

    @Test("given a money string, should tell gain/zero (green) from loss (red)",
          arguments: [("12.50", true), ("0", true), ("0.00", true), ("-0.01", false), ("", true)])
    func isNonNegative(value: String, expected: Bool) {
        #expect(ReportFormat.isNonNegative(value) == expected)
    }
}
