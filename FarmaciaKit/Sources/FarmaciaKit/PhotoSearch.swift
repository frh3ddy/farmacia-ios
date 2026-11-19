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

/// An image feature print as plain numbers (Vision's `VNFeaturePrintObservation`
/// stays in FarmaciaScan; the index caches these).
public enum FeatureVector {
    /// Cosine similarity, -1...1. Nil when the two can't be compared: different
    /// lengths (another Vision revision), empty, or all zeros.
    public static func similarity(_ a: [Float], _ b: [Float]) -> Double? {
        guard a.count == b.count else { return nil }
        var dot = 0.0, aa = 0.0, bb = 0.0
        for (x, y) in zip(a, b) {
            dot += Double(x) * Double(y)
            aa += Double(x) * Double(x)
            bb += Double(y) * Double(y)
        }
        guard aa > 0, bb > 0 else { return nil }
        return dot / (aa * bb).squareRoot()
    }
}

extension PhotoSearch {
    public struct Candidate: Equatable, Sendable {
        public let id: String
        public let name: String
        public let vector: [Float]?

        public init(id: String, name: String, vector: [Float]? = nil) {
            self.id = id
            self.name = name
            self.vector = vector
        }
    }

    // ponytail: fixed weights; tune from scan-bench's photo-search numbers (epic step 8).
    static let textWeight = 0.6
    static let imageWeight = 0.4
    /// Feature prints of unrelated products still score 0.2–0.58 (Vision revision 2,
    /// measured on the user's photos; the same box ≈ 0.8). Similarity up to this
    /// counts as no likeness at all, so a reference photo isn't a head start.
    // ponytail: fixed floor; tune with the weights from scan-bench (epic step 8).
    static let unrelatedFloor = 0.5

    /// Similarity above the unrelated floor, rescaled to 0...1.
    static func likeness(_ similarity: Double) -> Double {
        max((similarity - unrelatedFloor) / (1 - unrelatedFloor), 0)
    }

    /// Best first. Every candidate is kept (the grid scrolls past the top matches);
    /// equal scores fall back to name order, so no text and no photo is a plain list.
    public static func rank(_ candidates: [Candidate], lines: [String], photo: [Float]?) -> [Candidate] {
        candidates
            .map { candidate in
                let text = textScore(lines: lines, name: candidate.name)
                // Rescaled so unrelated (or opposite) looks add 0, the same as no photo.
                let similarity = photo.flatMap { p in candidate.vector.flatMap { FeatureVector.similarity(p, $0) } }
                let image = similarity.map(likeness) ?? 0
                return (candidate, textWeight * text + imageWeight * image)
            }
            .sorted { a, b in
                a.1 != b.1 ? a.1 > b.1
                    : a.0.name.localizedStandardCompare(b.0.name) == .orderedAscending
            }
            .map(\.0)
    }
}
