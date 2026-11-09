import Foundation

// MARK: - Label Name
//
// The product name printed on a photographed label: the biggest text, skipping
// what's printed big but isn't a name (lot, date, barcode digits, a bare
// amount, the sanitary registration, a web address). A brand and product
// printed at about the same size ("GENFAR" / "IBUPROFENO") are joined.

/// One OCR line: its text and its height relative to the photo (0...1).
public struct LabelLine: Equatable, Sendable {
    public let text: String
    public let height: Double

    public init(text: String, height: Double) {
        self.text = text
        self.height = height
    }
}

public enum LabelName {
    /// Lines within this fraction of the tallest name line count as part of the name.
    static let similarHeight = 0.85

    public static func pick(lines: [LabelLine]) -> String? {
        let candidates = lines
            .map { LabelLine(text: withoutPromo($0.text), height: $0.height) }
            .filter { isName($0.text) }
        guard let tallest = candidates.map(\.height).max() else { return nil }
        // Kept in reading order (OCR gives top to bottom): brand, then product.
        let name = candidates
            .filter { $0.height >= tallest * similarHeight }
            .prefix(2)
            .map { tidy($0.text) }
            .joined(separator: " ")
        return name
    }

    /// Printed big on Mexican packaging, but never the product's name: removed
    /// as whole words, so "NUEVO IBUPROFENO" keeps its name and "Renuevo" is untouched.
    private static let promo = #"(?i)[¡!]*\b(nuevo|oferta|gratis|promoci[oó]n|contenido neto)\b[!]*"#

    private static func withoutPromo(_ text: String) -> String {
        text.replacingOccurrences(of: promo, with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isName(_ text: String) -> Bool {
        let lower = text.lowercased()
        guard text.filter(\.isLetter).count >= 3 else { return false }
        if LotNumber.read(lines: [text]) != nil { return false }
        if ["www", "http", ".com", "@"].contains(where: lower.contains) { return false }
        // The sanitary registration ("Reg. San.", "Registro"), not names like Regaine.
        if lower.range(of: #"^reg(\.|istro\b)"#, options: .regularExpression) != nil { return false }
        if lower.range(of: #"\b(cad|exp|vence|caducidad)\b"#, options: .regularExpression) != nil { return false }
        if lower.range(of: #"\d{6,}"#, options: .regularExpression) != nil { return false }
        if lower.range(of: #"^\s*\d+([.,]\d+)?\s*(mg|g|ml|l|mcg|µg|%|ui)\s*$"#, options: .regularExpression) != nil { return false }
        return true
    }

    /// Shouted all-caps becomes title case; mixed case is the brand's own and is kept.
    private static func tidy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == trimmed.uppercased() else { return trimmed }
        return trimmed.capitalized(with: Locale(identifier: "es_MX"))
    }
}
