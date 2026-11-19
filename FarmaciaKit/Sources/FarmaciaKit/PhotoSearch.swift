import Foundation

// MARK: - Photo Search
//
// Buscar por foto (tasks/photo-search-epic.md): finds a product that has no
// barcode from a photo. Only "sin código" products are candidates.

public enum PhotoSearch {
    /// No code the scanner can match: no barcode, and a SKU that isn't one either
    /// (scans match both, `BarcodeLookup.matches`). Services (Yastás) aren't
    /// photographed, so they're left out; an unknown `tracksInventory` (older
    /// server) counts as a physical product.
    public static func isSinCodigo(sku: String?, gtin: String?, tracksInventory: Bool?) -> Bool {
        guard tracksInventory != false, trimmed(gtin).isEmpty else { return false }
        return !BarcodeLookup.isGTIN(trimmed(sku))
    }

    private static func trimmed(_ s: String?) -> String {
        s?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}

extension PhotoSearch {
    /// The share of the product name's words printed on the box (0...1). Case and
    /// accents are ignored, "500mg" reads as "500 mg", and a word of 5+ letters
    /// survives a one-letter OCR slip ("PARACETAMOI"). Numbers must match exactly,
    /// so the strength on the box tells 500 mg from 750 mg.
    public static func textScore(lines: [String], name: String) -> Double {
        let wanted = Set(words(name))
        guard !wanted.isEmpty else { return 0 }
        let read = Set(lines.flatMap(words))
        let found = wanted.filter { word in read.contains { sameWord($0, word) } }
        return Double(found.count) / Double(wanted.count)
    }

    /// Runs of letters or of digits, case- and accent-folded: "Jabón 500mg" → jabon, 500, mg.
    static func words(_ text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        var words: [String] = [], current = ""
        for c in folded {
            if !current.isEmpty, !(c.isLetter && current.last!.isLetter) && !(c.isNumber && current.last!.isNumber) {
                words.append(current)
                current = ""
            }
            if c.isLetter || c.isNumber { current.append(c) }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    private static func sameWord(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard a.count >= 5, b.count >= 5, a.allSatisfy(\.isLetter), b.allSatisfy(\.isLetter) else { return false }
        return withinOneEdit(Array(a), Array(b))
    }

    /// One substitution, insertion or deletion at most.
    private static func withinOneEdit(_ a: [Character], _ b: [Character]) -> Bool {
        guard abs(a.count - b.count) <= 1 else { return false }
        var i = 0, j = 0, edits = 0
        while i < a.count, j < b.count {
            if a[i] == b[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return false }
            if a.count > b.count { i += 1 } else if a.count < b.count { j += 1 } else { i += 1; j += 1 }
        }
        // A longer word's skip lines the ends up, so at most one letter is left over, and
        // only when nothing else differed.
        return true
    }
}
