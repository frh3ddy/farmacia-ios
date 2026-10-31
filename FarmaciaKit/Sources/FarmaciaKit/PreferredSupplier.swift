import Foundation

// MARK: - Preferred Supplier
//
// The receive form auto-picks the product's preferred supplier. It needs two
// lists that load separately (the product's suppliers, and all suppliers to
// pick from), so the form asks again whenever either arrives.

public enum PreferredSupplier {
    /// The supplier to select, or nil to leave the selection alone: nothing
    /// preferred, the user already chose one, or it isn't in the list yet.
    public static func pick(preferredId: String?, selectedId: String?, available: [String]) -> String? {
        guard selectedId == nil, let preferredId, available.contains(preferredId) else { return nil }
        return preferredId
    }
}
