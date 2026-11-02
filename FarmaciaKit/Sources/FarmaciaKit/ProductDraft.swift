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
    public var hasInitialStock = false
    public var syncToSquare = true
    public var soldAtAllLocations = true
    public var supplierId: String?
    public var hasPhoto = false

    /// A fresh form; `prefillSku` is the barcode it was opened from, if any.
    public init(prefillSku: String? = nil) {
        sku = prefillSku ?? ""
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
