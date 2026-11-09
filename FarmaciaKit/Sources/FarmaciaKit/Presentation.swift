import Foundation

// MARK: - Presentation
//
// The amount and/or count printed on a photographed label ("500 mg · 30
// tabletas"), which fills an empty Descripción in Nuevo producto.

public enum Presentation {
    private static let amount = #"(?i)\b(\d+(?:[.,]\d+)?)\s*(mg|mcg|µg|g|ml|l)\b"#
    /// "c/20" is "con 20"; abbreviated units are spelled out (see `spelled`).
    private static let count = #"(?i)\b(?:c/\s*)?(\d+)\s*(tabletas|tabs?|comprimidos|cápsulas|capsulas|caps|grageas|parches|sobres|piezas|pz(?:as?)?|ampolletas|óvulos)\b"#
    private static let spelled = ["tab": "tabletas", "tabs": "tabletas", "caps": "cápsulas",
                                  "pz": "piezas", "pza": "piezas", "pzas": "piezas"]

    public static func read(lines: [String]) -> String? {
        let parts = [first(amount, in: lines, unit: unitCase), first(count, in: lines, unit: { spelled[$0.lowercased()] ?? $0.lowercased() })]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func first(_ pattern: String, in lines: [String], unit: (String) -> String) -> String? {
        let regex = try! NSRegularExpression(pattern: pattern)
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let number = Range(match.range(at: 1), in: line),
               let name = Range(match.range(at: 2), in: line) {
                return "\(line[number]) \(unit(String(line[name])))"
            }
        }
        return nil
    }

    /// Lowercase units, except the liter: "1 L" reads better than "1 l".
    private static func unitCase(_ unit: String) -> String {
        unit.lowercased() == "l" ? "L" : unit.lowercased()
    }
}
