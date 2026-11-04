import Foundation

// MARK: - Product Codes
//
// The SKU and barcode lines a product card shows. A barcode that's only another
// form of the SKU (e.g. the 14-digit read of an EAN-13 SKU) shows once.

public enum ProductCodes {
    public enum Line: Equatable, Sendable {
        case sku(String)
        case barcode(String)
    }

    public static func lines(sku: String?, gtin: String?) -> [Line] {
        let sku = nonBlank(sku), gtin = nonBlank(gtin)
        var lines: [Line] = sku.map { [.sku($0)] } ?? []
        if let gtin, !BarcodeLookup.matches(sku: sku, gtin: nil, variants: BarcodeLookup.codeVariants(gtin)) {
            lines.append(.barcode(gtin))
        }
        return lines
    }

    private static func nonBlank(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        return s
    }
}
