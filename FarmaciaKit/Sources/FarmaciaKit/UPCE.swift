import Foundation

// MARK: - UPC-E
//
// UPC-E is a zero-suppressed UPC-A (GS1 General Specifications). Its check digit is the
// UPC-A's, so validating means expanding first. Scanners still report the 8 digits.

public enum UPCE {
    /// The 12-digit UPC-A an 8-digit UPC-E (number system 0 or 1) stands for.
    public static func expanded(_ code: String) -> String? {
        let c = Array(code)
        guard c.count == 8, c.allSatisfy({ $0.isASCII && $0.isNumber }), c[0] == "0" || c[0] == "1" else { return nil }
        let (n, d, check) = (c[0], Array(c[1...6]), c[7])
        let body: [Character] = switch d[5] {
        case "0", "1", "2": [d[0], d[1], d[5], "0", "0", "0", "0", d[2], d[3], d[4]]
        case "3": [d[0], d[1], d[2], "0", "0", "0", "0", "0", d[3], d[4]]
        case "4": [d[0], d[1], d[2], d[3], "0", "0", "0", "0", "0", d[4]]
        default: [d[0], d[1], d[2], d[3], d[4], "0", "0", "0", "0", d[5]]
        }
        return String([n] + body + [check])
    }
}
