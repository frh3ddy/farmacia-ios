import Foundation

// MARK: - Expiry Placement
//
// Where Recibir inventario puts "Lote y caducidad". Decided by the product's
// own history, not a category or a medication flag (categories are sometimes
// wrong, and non-medications expire too): it follows the latest receiving. A
// product never received gets it up top, switched on — most stock here expires.

public enum ExpiryPlacement: Equatable, Sendable {
    /// Right after Cantidad, "Tiene caducidad" on.
    case prominent
    /// At the bottom, switched off.
    case optional

    public init(expiriesNewestFirst: [Date?]) {
        self = expiriesNewestFirst.first.map { $0 == nil ? .optional : .prominent } ?? .prominent
    }
}
