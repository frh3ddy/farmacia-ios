import Foundation

// MARK: - Expiry Text
//
// Reads a lot's expiry from the text the camera sees on a box: "CAD 03/2027",
// "EXP 2027/03", "VENCE MAR 2027", "CAD: 15/03/2027" (the day is dropped, see
// `MonthYear`). A date after an expiry keyword wins. Manufacturing dates
// ("FAB 01/2025") are never read as the expiry. With no keyword, a date is
// used only when it's the only one on the box and hasn't passed. Prices
// ("$10.30") are never dates, and a month read with a zero ("0CT", "AG0") is
// read as the month.

public enum ExpiryText {
    /// The caducidad and where it was printed: its line, and what's before it on that line
    /// (where an unlabeled lote sits, see `LotNumber.unlabeled`).
    public struct Found: Equatable, Sendable {
        public let date: MonthYear
        public let line: Int
        public let prefix: String
    }

    public static func read(lines: [String], today: MonthYear) -> MonthYear? {
        find(lines: lines, today: today)?.date
    }

    public static func find(lines: [String], today: MonthYear) -> Found? {
        let lines = lines.map(normalize)
        for (i, line) in lines.enumerated() {
            guard let keyword = firstMatch(expiryKeyword, in: line) else { continue }
            let rest = String(line[keyword.upperBound...])
            // What's before the keyword may be the lot ("B24017 CAD 08/2027").
            if let date = dates(in: rest).first {
                return Found(date: date.date, line: i, prefix: String(line[..<keyword.lowerBound]))
            }
            // "CAD." alone, the date on the next line.
            if rest.allSatisfy({ !$0.isLetter && !$0.isNumber }), i + 1 < lines.count,
               let date = dates(in: lines[i + 1]).first {
                return Found(date: date.date, line: i + 1, prefix: date.prefix)
            }
        }
        let loose = lines.enumerated().flatMap { i, line -> [Found] in
            // A price line's number isn't a date, even without its "$" ("PRECIO MAX 12.50").
            guard firstMatch(priceLine, in: line) == nil else { return [] }
            // Drop what follows a manufacturing keyword on the line.
            let kept = firstMatch(madeKeyword, in: line).map { String(line[..<$0.lowerBound]) } ?? line
            return dates(in: kept)
                // Over 6 years either way it's a stray number, not a caducidad or a FAB date:
                // "12.50" isn't Dec 2050, a price read as "< 10.00" isn't Oct 2000.
                .filter { abs($0.date.months(since: today)) <= looseWindowMonths }
                .map { Found(date: $0.date, line: i, prefix: $0.prefix) }
        }
        guard loose.count == 1, let only = loose.first, !only.date.isBefore(today) else { return nil }
        return only
    }

    // MARK: Matching

    private static let expiryKeyword = regex(#"\b(CADUCIDAD|CADUCA|CAD|EXPIRA|EXPIRY|EXP|VENCE|VENC|VTO|VENCIMIENTO)\b"#)
    private static let madeKeyword = regex(#"\b(FABRICACION|FAB|ELAB|MFG|MFD)\b"#)
    private static let agoAsA60 = regex(#"(?<![A-Z])A6[O0](?=\s\d{2}(?!\d))"#)
    private static let lotKeyword = regex(#"\bLOTE?\b"#)
    private static let priceLine = regex(#"\b(PRECIO|MAX[A-Z]*|PUBLICO)\b|\bP\.?\s?M\.?\s?P\b"#)
    /// No medicine lasts longer (and a FAB date isn't older): a date with no keyword further
    /// from today than this is a stray number.
    private static let looseWindowMonths = 6 * 12

    private static let months = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
    private static let englishMonths = ["JAN": 1, "APR": 4, "AUG": 8, "SET": 9, "DEC": 12]

    private static let monthNames = (months + englishMonths.keys).joined(separator: "|")

    /// Leftmost date wins; at the same spot, the earlier alternative.
    private static let date = regex(
        #"(?<!\d)(?:"#
        + #"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})"#   // 1-3: DD/MM/YYYY
        + #"|(\d{4})[/\-.](\d{1,2})"#                       // 4-5: YYYY/MM
        + #"|(\d{1,2})[/\-.](\d{4}|\d{2})"#                 // 6-7: MM/YYYY
        + #"|(\d{1,2})\s+(\d{4})"#                          // 8-9: MM YYYY
        + #"|(?:\d{1,2}[\s\-/.]*)?\b("# + monthNames
        + #")[A-Z]*\.?[\s\-/.]*(\d{4}|\d{2})"#          // 10-11: [DD] MAR 2027
        + #")(?!\d)"#
    )

    private static func dates(in text: String) -> [(date: MonthYear, prefix: String)] {
        let ns = text as NSString
        return date.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            func group(_ i: Int) -> String? {
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            let date: MonthYear?
            if let month = group(2), let year = group(3) { date = make(month: Int(month), year: year) }
            else if let year = group(4), let month = group(5) { date = make(month: Int(month), year: year) }
            else if let month = group(6), let year = group(7) { date = make(month: Int(month), year: year) }
            else if let month = group(8), let year = group(9) { date = make(month: Int(month), year: year) }
            else if let name = group(10), let year = group(11) { date = make(month: monthNumber(name), year: year) }
            else { date = nil }
            return date.map { ($0, ns.substring(to: m.range.location)) }
        }
    }

    private static func make(month: Int?, year: String) -> MonthYear? {
        guard let month, (1...12).contains(month), let y = Int(year) else { return nil }
        let full = year.count == 2 ? 2000 + y : y
        guard (2000...2099).contains(full) else { return nil }
        return MonthYear(year: full, month: month)
    }

    private static func monthNumber(_ name: String) -> Int? {
        months.firstIndex(of: name).map { $0 + 1 } ?? englishMonths[name]
    }

    private static func normalize(_ line: String) -> String {
        var line = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).uppercased()
        for (pattern, template) in fixes {
            line = pattern.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: template)
        }
        // AGO read "A60"/"A6O" (G as 6): only spaced from its year ("A60 27") and never on a lote
        // line, since "A6029" is what a lote code looks like ("A6028" stays unread, never guessed).
        if firstMatch(lotKeyword, in: line) == nil {
            line = agoAsA60.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "AGO")
        }
        return line
    }

    /// A price is never a date ("$10.30" isn't October 2030); dot-matrix O read as a zero.
    private static let fixes: [(NSRegularExpression, String)] = [
        (regex(#"\$\s*\d[\d,]*(?:\.\d{1,2})?"#), " "),
        (regex(#"(?<![A-Z])0CT"#), "OCT"),
        (regex(#"(?<![A-Z])AG0"#), "AGO"),
        (regex(#"(?<![A-Z])N0V"#), "NOV"),
        // A lote glued to "AGO 27" ("254875AGO 27") is split off. Only before a spaced 2-digit
        // year, so a month inside a lote code ("A23DIC45") stays part of it.
        (regex(#"(\d)("# + monthNames + #")(?=\s+\d{2}(?!\d))"#), "$1 $2"),
    ]

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // swiftlint:disable:next force_try — constant patterns, covered by tests.
        try! NSRegularExpression(pattern: pattern)
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> Range<String.Index>? {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)).flatMap { Range($0.range, in: text) }
    }
}

extension MonthYear {
    func isBefore(_ other: MonthYear) -> Bool {
        (year, month) < (other.year, other.month)
    }

    func months(since other: MonthYear) -> Int {
        (year - other.year) * 12 + (month - other.month)
    }
}
