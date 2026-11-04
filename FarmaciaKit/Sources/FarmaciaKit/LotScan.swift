import Foundation

// MARK: - Lot Scan
//
// What the lot camera has found so far: text lines and barcodes in view. A
// GS1 DataMatrix wins over the printed text for each field it carries.
// Complete — the scanner fills the form and closes — once it has both.

public struct LotScan: Equatable, Sendable {
    public let lot: String?
    public let expiry: MonthYear?

    public init(lines: [String], barcodes: [String], today: MonthYear) {
        let code = barcodes.lazy.compactMap(GS1Code.init(payload:)).first
        lot = code?.lot ?? LotNumber.read(lines: lines)
        expiry = code?.expiry ?? ExpiryText.read(lines: lines, today: today)
    }

    public var isComplete: Bool { lot != nil && expiry != nil }
}
