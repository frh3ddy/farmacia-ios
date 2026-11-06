import Foundation

// MARK: - Lot Scan
//
// What the lot camera has found so far: text lines and barcodes in view. A
// GS1 DataMatrix wins over the printed text for each field it carries.
// Complete — the scanner fills the form and closes — once it has both. The
// caducidad is what matters (the lote is optional), so a caducidad alone is
// taken too, after a short wait in case the lot is about to be read.

public struct LotScan: Equatable, Sendable {
    public let lot: String?
    public let expiry: MonthYear?

    public init(lines: [String], barcodes: [String], today: MonthYear) {
        let code = barcodes.lazy.compactMap(GS1Code.init(payload:)).first
        lot = code?.lot ?? LotNumber.read(lines: lines)
        expiry = code?.expiry ?? ExpiryText.read(lines: lines, today: today)
    }

    public var isComplete: Bool { lot != nil && expiry != nil }

    public enum AutoAccept: Equatable, Sendable {
        case now
        /// A caducidad with no lot: taken after `lotGrace` if the lot still hasn't been read.
        case afterGrace
        /// Nothing worth closing for yet (a lot alone): the user taps Usar.
        case no
    }

    /// How long a caducidad alone waits for the lot. Live text reads a box's lines a frame or two
    /// apart; tune this if lots are missed (too short) or the scan feels slow (too long).
    public static let lotGrace: Duration = .seconds(1)

    public var autoAccept: AutoAccept {
        if isComplete { return .now }
        return expiry != nil ? .afterGrace : .no
    }
}
