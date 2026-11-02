import Foundation
import Testing
@testable import FarmaciaKit

/// Amount fields keep what the user typed as text and read the number on every
/// keystroke, so a form's Crear/Guardar enables without leaving the field
/// (`TextField(value:format:)` only writes back when editing ends, and the
/// number pad has no return key).
struct AmountTextParseTests {
    @Test("given \"12.5\", should be 12.5")
    func decimal() {
        #expect(AmountText.parse("12.5") == 12.5)
    }

    @Test("given empty or blank text, should be nil")
    func empty() {
        #expect(AmountText.parse("") == nil)
        #expect(AmountText.parse("  ") == nil)
    }

    @Test("given a comma as the decimal separator, should read it as one")
    func commaDecimal() {
        #expect(AmountText.parse("12,5") == 12.5)
    }

    @Test("given thousands separators, should ignore them")
    func thousands() {
        #expect(AmountText.parse("1,234.50") == 1234.5)
    }

    @Test("given a lone separator or letters, should be nil")
    func notANumber() {
        #expect(AmountText.parse(".") == nil)
        #expect(AmountText.parse("abc") == nil)
    }
}

/// Showing a value that came from elsewhere (a prefilled cost) in the field.
struct AmountTextStringTests {
    @Test("given 12.0, should show \"12\"; given 12.5, should show \"12.5\"")
    func trimsZeros() {
        #expect(AmountText.string(from: 12.0) == "12")
        #expect(AmountText.string(from: 12.5) == "12.5")
    }

    @Test("given nil, should show an empty field")
    func none() {
        #expect(AmountText.string(from: nil) == "")
    }
}
