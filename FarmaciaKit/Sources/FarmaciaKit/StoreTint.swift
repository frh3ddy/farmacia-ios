import Foundation

// MARK: - Store Tint
//
// Each store's strip color on the stock-changing sheets, so receiving into the
// wrong store is visible before saving. Picked from the store id, so every
// device and employee sees the same color for the same store.

// ponytail: 6 colors picked by hash — today's 2 stores are distinct (pinned in
// StoreTintTests); a new store has a 1-in-6 chance per existing store of sharing
// a color. If that happens, store an owner-picked color on Location server-side.

public enum StoreTint {
    public static func paletteIndex(forLocationId id: String, paletteCount: Int) -> Int {
        precondition(paletteCount > 0, "empty palette")
        // 64-bit FNV-1a, not Hasher: Swift seeds that per launch.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return Int(hash % UInt64(paletteCount))
    }

    /// With one store there's no wrong store to receive into.
    public static func showsStrip(storeCount: Int) -> Bool {
        storeCount > 1
    }
}
