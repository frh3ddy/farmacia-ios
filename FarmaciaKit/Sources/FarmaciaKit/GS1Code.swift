import Foundation

// MARK: - GS1 Code
//
// A box's GS1 DataMatrix carries the lot (AI 10) and the expiry (AI 17,
// YYMMDD; day 00 means "the month") exactly, so it wins over reading the
// printed text. Takes the scanner's raw payload (GS-separated, maybe with a
// "]d2" symbology prefix) or the printed "(17)270331(10)23A45" form.

public struct GS1Code: Equatable, Sendable {
    public let lot: String?
    public let expiry: MonthYear?

    public init?(payload: String) {
        let fields = payload.contains("(") ? Self.printedFields(payload) : Self.rawFields(payload)
        lot = fields["10"].flatMap { $0.isEmpty ? nil : $0 }
        expiry = fields["17"].flatMap(Self.month)
        if lot == nil && expiry == nil { return nil }
    }

    /// AIs with a fixed length; 10 (lot) and 21 (serial) run to a GS or the end.
    private static let fixedLength = ["00": 18, "01": 14, "02": 14, "11": 6, "12": 6, "13": 6, "15": 6, "16": 6, "17": 6]
    private static let variable: Set = ["10", "21", "22"]

    private static func rawFields(_ payload: String) -> [String: String] {
        var rest = Substring(payload)
        for prefix in ["]d2", "]C1", "]Q3"] where rest.hasPrefix(prefix) { rest = rest.dropFirst(prefix.count) }
        var fields: [String: String] = [:]
        while rest.count >= 2 {
            let ai = String(rest.prefix(2))
            rest = rest.dropFirst(2)
            if let length = fixedLength[ai] {
                guard rest.count >= length else { break }
                fields[ai] = String(rest.prefix(length))
                rest = rest.dropFirst(length)
            } else if variable.contains(ai) {
                let value = rest.prefix { $0 != "\u{1D}" }
                fields[ai] = String(value)
                rest = rest.dropFirst(value.count)
            } else {
                break // An AI we don't read (3–4 digits, or not GS1 at all).
            }
            if rest.first == "\u{1D}" { rest = rest.dropFirst() }
        }
        return fields
    }

    private static func printedFields(_ payload: String) -> [String: String] {
        var fields: [String: String] = [:]
        for part in payload.split(separator: "(") {
            let pair = part.split(separator: ")", maxSplits: 1)
            if pair.count == 2 { fields[String(pair[0])] = String(pair[1]) }
        }
        return fields
    }

    /// YYMMDD → its month.
    private static func month(_ yymmdd: String) -> MonthYear? {
        guard yymmdd.count == 6, let yy = Int(yymmdd.prefix(2)), let mm = Int(yymmdd.dropFirst(2).prefix(2)),
              (1...12).contains(mm) else { return nil }
        return MonthYear(year: 2000 + yy, month: mm)
    }
}
