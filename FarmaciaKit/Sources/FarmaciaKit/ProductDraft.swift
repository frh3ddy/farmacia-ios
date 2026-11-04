import Foundation

// MARK: - Product Draft
//
// What the new-product form holds, as a value, so "has the user entered
// anything?" is a comparison with how the form started. Drives the form's
// protection against losing work: no swipe-to-dismiss, and Cancelar asks
// before discarding, once there are changes.

public struct ProductDraft: Equatable, Sendable {
    public var name = ""
    public var sku = ""
    /// The barcode; optional, but when typed it must be a GTIN (8/12/13/14 digits).
    public var gtin = ""
    public var description = ""
    public var sellingPrice: Double?
    public var costPrice: Double?
    public var initialStock: Int?
    public var syncToSquare = true
    public var soldAtAllLocations = true
    public var supplierId: String?
    public var hasPhoto = false

    /// A fresh form; `prefillBarcode` is the code it was scanned from, if any. It
    /// fills the barcode, not the SKU: a SKU is unique, a barcode can be shared.
    public init(prefillBarcode: String? = nil) {
        gtin = prefillBarcode ?? ""
    }

    /// Empty, or 8/12/13/14 digits (the server's rule).
    public var barcodeIsValid: Bool {
        let code = gtin.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty || BarcodeLookup.isGTIN(code)
    }

    /// A quantity creates initial stock — there's no switch for it.
    public var createsInitialStock: Bool {
        (initialStock ?? 0) > 0
    }

    /// Crear: a name and a positive price; with a quantity, its cost too
    /// (0 is fine). A cost without a quantity blocks saving instead of being
    /// dropped silently.
    public var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let price = sellingPrice, price > 0,
              barcodeIsValid
        else { return false }
        if createsInitialStock {
            guard let cost = costPrice, cost >= 0 else { return false }
        } else if costPrice != nil {
            return false
        }
        return true
    }

    /// Why Crear is off, for values the user entered — shown under the field
    /// that fixes it. Empty required fields aren't listed: their labels say so.
    public enum Issue: Hashable, Sendable {
        case priceNotPositive, quantityNeeded, costNeeded, barcodeInvalid

        public var message: String {
            switch self {
            case .priceNotPositive: "El precio debe ser mayor a $0."
            case .quantityNeeded: "Indica la cantidad para registrar este costo, o borra el costo."
            case .costNeeded: "Indica el costo unitario de esta cantidad (0 si fue regalo)."
            case .barcodeInvalid: "El código de barras debe tener 8, 12, 13 o 14 dígitos."
            }
        }
    }

    public var issues: [Issue] {
        var issues: [Issue] = []
        if !barcodeIsValid { issues.append(.barcodeInvalid) }
        if let price = sellingPrice, price <= 0 { issues.append(.priceNotPositive) }
        if createsInitialStock, costPrice == nil { issues.append(.costNeeded) }
        if !createsInitialStock, costPrice != nil { issues.append(.quantityNeeded) }
        return issues
    }

    /// Whether the optional fields (Más detalles: description, stores, Square)
    /// hold anything. The SKU and barcode aren't among them: they show with the
    /// essentials (SKU "Automático" when empty).
    public var hasDetails: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !soldAtAllLocations
            || !syncToSquare
    }

    /// Text is compared trimmed: spaces alone aren't work worth protecting.
    public func hasChanges(from start: ProductDraft) -> Bool {
        trimmed != start.trimmed
    }

    private var trimmed: ProductDraft {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.sku = sku.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.gtin = gtin.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}
