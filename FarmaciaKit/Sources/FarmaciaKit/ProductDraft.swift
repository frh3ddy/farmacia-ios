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
    public var description = ""
    public var sellingPrice: Double?
    public var costPrice: Double?
    public var initialStock: Int?
    public var syncToSquare = true
    public var soldAtAllLocations = true
    public var supplierId: String?
    public var hasPhoto = false

    /// A fresh form; `prefillSku` is the barcode it was opened from, if any.
    public init(prefillSku: String? = nil) {
        sku = prefillSku ?? ""
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
              let price = sellingPrice, price > 0
        else { return false }
        if createsInitialStock {
            guard let cost = costPrice, cost >= 0 else { return false }
        } else if costPrice != nil {
            return false
        }
        return true
    }

    /// Whether the optional fields (Más detalles: description, stores, Square)
    /// hold anything. The SKU isn't one of them: it shows with the essentials,
    /// "Automático" when empty.
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
        copy.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}
