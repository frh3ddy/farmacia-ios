import Foundation

// MARK: - Aging Sentence
//
// How long the stock has sat on the shelf, in words and in units (not lots),
// on the `BatchAge` buckets: "las 2 unidades llevan menos de 30 días en piso",
// "1 de 3 unidades lleva más de 90 días". The oldest bucket with units speaks.
public enum AgingSentence {
    public static func text(lots: [BatchValuation]) -> String? {
        let total = lots.reduce(0) { $0 + max($1.quantity, 0) }
        guard total > 0 else { return nil }
        func units(_ tone: Tone) -> Int {
            lots.filter { BatchAge.tone(days: $0.age) == tone }.reduce(0) { $0 + max($1.quantity, 0) }
        }
        let old = units(.critical), slow = units(.caution)
        if old > 0 { return phrase(old, of: total, "más de 90 días") }
        if slow > 0 { return phrase(slow, of: total, "entre 31 y 90 días") }
        return phrase(total, of: total, "menos de 30 días") + " en piso"
    }

    private static func phrase(_ n: Int, of total: Int, _ span: String) -> String {
        if n == total {
            return total == 1 ? "la unidad lleva \(span)" : "las \(total) unidades llevan \(span)"
        }
        return "\(n) de \(total) unidades \(n == 1 ? "lleva" : "llevan") \(span)"
    }
}
