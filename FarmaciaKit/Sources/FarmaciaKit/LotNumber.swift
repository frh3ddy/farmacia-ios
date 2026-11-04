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
              lot.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "/") })
        else { return nil }
        return lot
    }
}
