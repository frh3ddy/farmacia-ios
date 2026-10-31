import Foundation

// MARK: - Stock Entry
//
// A product sold only at one store (Product.soldOnlyAtLocationId) is hidden from
// the others' lists, so stock added there would be invisible; the API refuses it
// (PRODUCT_NOT_SOLD_AT_LOCATION). Removals stay allowed everywhere, so stray stock
// can be cleaned up.

public enum StockEntry {
    /// Whether stock may be received or added (found, return) at the current store.
    /// `soldOnlyAtLocationId` nil means the product is sold at every store.
    public static func canAdd(soldOnlyAtLocationId: String?, currentLocationId: String?) -> Bool {
        guard let soldOnlyAtLocationId else { return true }
        return soldOnlyAtLocationId == currentLocationId
    }
}
