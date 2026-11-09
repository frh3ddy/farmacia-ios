import Foundation

// MARK: - Model Name
//
// Apple Intelligence's answer, made fit for the Nombre field: no surrounding
// quotes, no final period, single spaces. Blank or rambling (> 60 characters)
// isn't a name, and the photo falls back to Vision's reading.

public enum ModelName {
    static let maxLength = 60

    public static func clean(_ raw: String) -> String? {
        let quotes = CharacterSet(charactersIn: "\"'«»“”‘’")
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(quotes))
        while text.hasSuffix(".") { text.removeLast() }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines.union(quotes))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty, text.count <= maxLength else { return nil }
        return text
    }
}
