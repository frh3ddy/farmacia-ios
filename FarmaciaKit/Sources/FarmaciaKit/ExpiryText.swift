import Foundation

// MARK: - Expiry Text
//
// Reads a lot's expiry from the text the camera sees on a box: "CAD 03/2027",
// "EXP 2027/03", "VENCE MAR 2027", "CAD: 15/03/2027" (the day is dropped, see
// `MonthYear`). A date after an expiry keyword wins. Manufacturing dates
// ("FAB 01/2025") are never read as the expiry. With no keyword, a date is
// used only when it's the only one on the box and hasn't passed.

public enum ExpiryText {
    public static func read(lines: [String], today: MonthYear) -> MonthYear? {
        let lines = lines.map(normalize)
        for (i, line) in lines.enumerated() {
            guard let keyword = firstMatch(expiryKeyword, in: line) else { continue }
            let rest = String(line[keyword.upperBound...])
            if let date = firstDate(in: rest) { return date }
            // "CAD." alone, the date on the next line.
            if rest.allSatisfy({ !$0.isLetter && !$0.isNumber }), i + 1 < lines.count,
               let date = firstDate(in: lines[i + 1]) {
                return date
            }
        }
        let loose = lines.flatMap { line -> [MonthYear] in
            // Drop what follows a manufacturing keyword on the line.
            let kept = firstMatch(madeKeyword, in: line).map { String(line[..<$0.lowerBound]) } ?? line
            return dates(in: kept)
        }
        guard loose.count == 1, let only = loose.first, !only.isBefore(today) else { return nil }
        return only
    }

    // MARK: Matching

    private static let expiryKeyword = regex(#"\b(CADUCIDAD|CADUCA|CAD|EXPIRA|EXPIRY|EXP|VENCE|VENC|VTO|VENCIMIENTO)\b"#)
    private static let madeKeyword = regex(#"\b(FABRICACION|FAB|ELAB|MFG|MFD)\b"#)

    private static let months = ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]
    private static let englishMonths = ["JAN": 1, "APR": 4, "AUG": 8, "SET": 9, "DEC": 12]

    /// Leftmost date wins; at the same spot, the earlier alternative.
    private static let date = regex(
        #"(?<!\d)(?:"#
        + #"(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})"#   // 1-3: DD/MM/YYYY
        + #"|(\d{4})[/\-.](\d{1,2})"#                       // 4-5: YYYY/MM
        + #"|(\d{1,2})[/\-.](\d{4}|\d{2})"#                 // 6-7: MM/YYYY
        + #"|(\d{1,2})\s+(\d{4})"#                          // 8-9: MM YYYY
        + #"|(?:\d{1,2}[\s\-/.]*)?\b("# + (months + englishMonths.keys).joined(separator: "|")
        + #")[A-Z]*\.?[\s\-/.]*(\d{4}|\d{2})"#          // 10-11: [DD] MAR 2027
        + #")(?!\d)"#
    )

    private static func dates(in text: String) -> [MonthYear] {
        let ns = text as NSString
        return date.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            func group(_ i: Int) -> String? {
                let r = m.range(at: i)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            if let month = group(2), let year = group(3) { return make(month: Int(month), year: year) }
            if let year = group(4), let month = group(5) { return make(month: Int(month), year: year) }
            if let month = group(6), let year = group(7) { return make(month: Int(month), year: year) }
            if let month = group(8), let year = group(9) { return make(month: Int(month), year: year) }
            if let name = group(10), let year = group(11) { return make(month: monthNumber(name), year: year) }
            return nil
        }
    }

    private static func firstDate(in text: String) -> MonthYear? { dates(in: text).first }

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
        line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).uppercased()
    }

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
}
