import Foundation

// MARK: - Lot Number
//
// Reads the lot from the text the camera sees on a box: "LOTE: A23B45",
// "LOT A23B45", "L. 2304567", or "LOTE" with the lot on the next line. A lot
// is one word with at least one digit ("A23B45", "23-0456"), so it stops at
// the next space ("LOTE: A23B45 CAD 03/27").

public enum LotNumber {
    public static func read(lines: [String]) -> String? {
        let lines = lines.map { $0.uppercased() }
        for (i, line) in lines.enumerated() {
            guard let m = keyword.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let end = Range(m.range, in: line)?.upperBound else { continue }
            let rest = line[end...].trimmingCharacters(in: .whitespaces)
            if rest.isEmpty {
                if i + 1 < lines.count, let lot = lot(in: lines[i + 1]) { return lot }
                continue
            }
            if let lot = lot(in: rest) { return lot }
        }
        return nil
    }

    /// A lot with no "LOTE" beside it (labels in a header, or none at all): the first lot-looking
    /// number printed with the caducidad, before the date on its line, else on one of the two
    /// lines above it. A guess: the form shows it to check.
    /// Lines come in reading order (`ReadingOrder`), so "above" means above on the box.
    public static func unlabeled(lines: [String], near found: ExpiryText.Found) -> String? {
        if !isOtherNumberLine(lines[found.line]), let lot = printedLot(in: found.prefix) { return lot }
        for back in 1...2 where found.line - back >= 0 {
            let line = lines[found.line - back]
            if !isOtherNumberLine(line), let lot = printedLot(in: line.uppercased()) { return lot }
        }
        return nil
    }

    /// Lines with numbers that aren't the lot: the sanitary registration ("Reg. No. 123M2015 SSA IV"),
    /// the maker's address (postal code "C.P. 54080", "S.A. de C.V.") and phone ("Tel.", "Atención 800 …").
    private static let otherNumberLine = try! NSRegularExpression(
        pattern: #"\b(REG|SSA|TEL|TELEFONO|ATENCION|LADA|800)\b|\bC\.?\s?P\b|\bS\.?\s?A\.?\s+DE\s+C\.?\s?V\b"#
    )
    private static let amount = try! NSRegularExpression(pattern: #"^\d+(MG|MCG|G|KG|ML|L|KJ|KCAL|UI)$"#)
    private static let registrationNumber = try! NSRegularExpression(pattern: #"^\d{2,4}M\d{4}$"#)

    private static func isOtherNumberLine(_ line: String) -> Bool {
        let line = line.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).uppercased()
        return otherNumberLine.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    /// The first word that looks like a printed lot: 5–20 letters and digits with at least 3
    /// digits. Prices ("$138.00", "186.00"), times ("10:11") and amounts ("700MG") aren't.
    private static func printedLot(in text: String) -> String? {
        text.split(whereSeparator: \.isWhitespace).lazy.map(String.init).first { word in
            (5...20).contains(word.count)
                && amount.firstMatch(in: word, range: NSRange(word.startIndex..., in: word)) == nil
                && word.filter(\.isNumber).count >= 3
                && word.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
                && !isOtherNumber(word)
        }
    }

    /// Numbers printed near the lote that aren't one: barcode digits (GTIN-12/13/14; 8-digit
    /// lots stay, "25010178") and the sanitary registration number ("123M2015").
    private static func isOtherNumber(_ word: String) -> Bool {
        (word.allSatisfy(\.isNumber) && (12...14).contains(word.count))
            || registrationNumber.firstMatch(in: word, range: NSRange(word.startIndex..., in: word)) != nil
    }

    /// "LOTE", "LOT", "LT", "L." and what joins them to the lot (":", "Nº", "#").
    private static let keyword = try! NSRegularExpression(
        pattern: #"\b(LOTE|LOT|LT|L)\b\s*(N[O0º°]?\.?\s*)?[.:#º°\-]*"#
    )

    /// The first word, if it looks like a lot.
    private static func lot(in text: String) -> String? {
        guard let word = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        let lot = String(word).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        guard (3...20).contains(lot.count),
              lot.contains(where: \.isNumber),
              lot.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "/") }),
              !isOtherNumber(lot)
        else { return nil }
        return lot
    }
}
