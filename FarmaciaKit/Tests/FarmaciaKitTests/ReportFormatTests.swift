import Foundation
import Testing
@testable import FarmaciaKit

struct ReportFormatTests {
    let mx = Locale(identifier: "es_MX")

    @Test("given an API money string, should format as MXN currency",
          arguments: [("1234.5", "$1,234.50"), ("0", "$0.00"), ("-89.999", "-$90.00"), ("12.5000", "$12.50")])
    func currency(value: String, expected: String) {
        #expect(ReportFormat.currency(value, locale: mx) == expected)
    }

    @Test("given a cash value of 12345.678, should show $12,345.68")
    func currencyDouble() {
        #expect(ReportFormat.currency(12345.678, locale: mx) == "$12,345.68")
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

    @Test("given a profit of 0 / 12.50 / -3, tone should be positive / positive / critical",
          arguments: [("0", Tone.positive), ("12.50", .positive), ("-3", .critical)])
    func gainLossTone(amount: String, expected: Tone) {
        #expect(ReportFormat.tone(amount) == expected)
    }
}

/// The big-number money style: symbol, whole part, cents set smaller ("$220.00").
struct CurrencyPartsTests {
    let mx = Locale(identifier: "es_MX")

    @Test("given 220, should split into \"$\", \"220\", \".00\"")
    func whole() {
        let parts = ReportFormat.currencyParts(220, locale: mx)
        #expect(parts == .init(symbol: "$", whole: "220", fraction: ".00"))
    }

    @Test("given 1234.5, should keep grouping in the whole part and cents in the fraction")
    func grouped() {
        let parts = ReportFormat.currencyParts(1234.5, locale: mx)
        #expect(parts == .init(symbol: "$", whole: "1,234", fraction: ".50"))
    }

    @Test("given -89.999, should round and keep the sign on the symbol")
    func negative() {
        let parts = ReportFormat.currencyParts(-89.999, locale: mx)
        #expect(parts == .init(symbol: "-$", whole: "90", fraction: ".00"))
    }
}
