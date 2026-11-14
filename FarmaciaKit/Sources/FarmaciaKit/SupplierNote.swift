import Foundation

/// A supplier note as staff see it. The cutover wrote "Migrated from cutover <uuid>" on
/// every migrated supplier (farmacia-ops inventory-migration); it stays in the database
/// but isn't shown.
public enum SupplierNote {
    public static func display(_ note: String?) -> String? {
        guard let note else { return nil }
        var cleaned = note.replacingOccurrences(of: #"(\s*[·;,–-]\s*)?Migrated from cutover [0-9a-fA-F-]+"#,
                                                with: "", options: .regularExpression)
        // Separators left at the ends only when the phrase was removed ("-10% en caja" keeps its dash).
        let edges = cleaned == note ? CharacterSet() : CharacterSet(charactersIn: "·;,–-")
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(edges))
        return cleaned.isEmpty ? nil : cleaned
    }
}
