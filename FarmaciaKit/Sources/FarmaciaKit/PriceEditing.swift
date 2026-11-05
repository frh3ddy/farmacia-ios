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

    /// Where a new price goes: every store for the owner (tasks/price-all-locations-epic.md),
    /// unless the product is sold at one store only. A manager prices their own store.
    /// A receiving uses it as is; Editar Precio starts its switch from it.
    public static func appliesToAllLocations(isOwner: Bool, soldOnlyAtLocationId: String?) -> Bool {
        isOwner && soldOnlyAtLocationId == nil
    }

    /// Under the price, in Editar Precio and in a receiving: where the new price applies.
    /// `inSquare`: the product is in Square (`hasSquareSync`); if not, Square isn't mentioned.
    public static func scopeNote(allLocations: Bool, syncToSquare: Bool, inSquare: Bool, storeName: String, isOwner: Bool) -> String {
        let stores = allLocations ? "Se aplica en todas las sucursales" : "Solo cambia en \(storeName)"
        let square = !inSquare ? "."
            : !syncToSquare ? "; Square POS sigue mostrando el precio anterior."
            : allLocations ? " y en Square POS." : " y en su Square POS."
        let others = isOwner ? "" : " El precio de las demás sucursales lo cambia el dueño."
        return stores + square + others
    }

    /// Editar Precio's Guardar: a positive price that differs from the current
    /// one (or a first price for a product without one).
    public static func canSave(newPrice: Double?, currentPrice: Double?) -> Bool {
        guard let newPrice, newPrice > 0 else { return false }
        return newPrice != currentPrice
    }
}
