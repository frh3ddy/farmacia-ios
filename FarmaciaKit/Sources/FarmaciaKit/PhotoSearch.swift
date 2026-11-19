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
