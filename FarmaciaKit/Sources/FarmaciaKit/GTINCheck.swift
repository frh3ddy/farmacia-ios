import Foundation

// MARK: - GTIN check digit
//
// GS1 mod-10 (the public GS1 General Specifications): from the right, excluding the
// check digit, digits are weighted 3, 1, 3, 1…; the check digit brings the sum to a
// multiple of 10. One rule covers EAN-8, UPC-A (12), EAN-13 and GTIN-14.

public enum GTINCheck {
    public static func isValid(_ code: String) -> Bool {
        guard [8, 12, 13, 14].contains(code.count), code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return false }
        let digits = code.compactMap(\.wholeNumberValue)
        let sum = digits.dropLast().reversed().enumerated()
            .reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 3 : 1) }
        return (10 - sum % 10) % 10 == digits.last
    }
}
