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
    /// (0 is fine). A cost without a quantity is fine: it drives the suggested
    /// price and isn't sent (no stock to cost).
    public var canSave: Bool { issues.isEmpty }

    /// What Crear needs, shown under the field that fixes it after the first
    /// tap. Form order: name, cost, price, barcode — focus goes to the first.
    public enum Issue: Hashable, Sendable {
        case nameMissing, costNeeded, priceMissing, priceNotPositive, barcodeInvalid

        public var message: String {
            switch self {
            case .nameMissing: "Escribe el nombre del producto."
            case .costNeeded: "Indica el costo por unidad del inventario inicial (0 si fue regalo)."
            case .priceMissing: "Indica el precio de venta."
            case .priceNotPositive: "El precio debe ser mayor a $0."
            case .barcodeInvalid: "El código de barras debe tener 8, 12, 13 o 14 dígitos."
            }
        }
    }

    public var issues: [Issue] {
        var issues: [Issue] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append(.nameMissing) }
        if createsInitialStock, (costPrice ?? -1) < 0 { issues.append(.costNeeded) }
        if let price = sellingPrice {
            if price <= 0 { issues.append(.priceNotPositive) }
        } else {
            issues.append(.priceMissing)
        }
        if !barcodeIsValid { issues.append(.barcodeInvalid) }
        return issues
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
