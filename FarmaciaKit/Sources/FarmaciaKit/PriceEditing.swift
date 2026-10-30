import Foundation

// MARK: - Price Editing
//
// Who may change a selling price, matching PATCH /products/:id/price on the API.

public enum PriceEditing {
    /// Owners and managers, never on a Yastás product: it has no set price (its
    /// revenue is entered on the Yastás screen) and is the only kind that doesn't
    /// track stock. An unknown `tracksInventory` (older cached copy) counts as a normal product.
    public static func canEdit(isOwner: Bool, isManager: Bool, tracksInventory: Bool?) -> Bool {
        (isOwner || isManager) && tracksInventory != false
    }

    /// Only the owner may change the price at every store; a manager prices their own store.
    public static func canApplyToAllLocations(isOwner: Bool) -> Bool {
        isOwner
    }
}
