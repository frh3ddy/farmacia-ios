import Foundation

// MARK: - Lot Scan
//
// What the lot camera has found so far: text lines and barcodes in view. A
// GS1 DataMatrix wins over the printed text for each field it carries.
// The caducidad is what matters (the lote is optional): the scanner fills the
// form and closes as soon as it reads one, with the lote if it has it. Some
// boxes show the date for a split second before it's lost, so it never waits.

public struct LotScan: Equatable, Sendable {
    public let lot: String?
    public let expiry: MonthYear?

    public init(lines: [String], barcodes: [String], today: MonthYear) {
        let code = barcodes.lazy.compactMap(GS1Code.init(payload:)).first
        let lines = lines.map(Self.joinSpacedCharacters)
        let found = ExpiryText.find(lines: lines, today: today)
        lot = code?.lot ?? LotNumber.read(lines: lines) ?? found.flatMap { LotNumber.unlabeled(lines: lines, near: $0) }
        expiry = code?.expiry ?? found?.date
    }

    /// Spaced dot-matrix ("2 5 0 1 0 1 7 8", "E N E  2 7") read as words: runs of
    /// one-character words are joined ("25010178", "ENE27").
    static func joinSpacedCharacters(_ line: String) -> String {
        var words: [String] = []
        var run = ""
        for word in line.split(whereSeparator: \.isWhitespace).map(String.init) {
            if word.count == 1 {
                run += word
            } else {
                if !run.isEmpty { words.append(run); run = "" }
                words.append(word)
            }
        }
        if !run.isEmpty { words.append(run) }
        return words.joined(separator: " ")
    }

    public var isComplete: Bool { lot != nil && expiry != nil }

    public enum AutoAccept: Equatable, Sendable {
        /// A caducidad: fill the form and close, with the lote if it was read too.
        case now
        /// Nothing worth closing for yet (a lote alone): the user taps Usar.
        case no
    }

    public var autoAccept: AutoAccept { expiry != nil ? .now : .no }
}
