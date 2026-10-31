import Foundation

// MARK: - Product Cache Rules
//
// The on-device product cache keeps one row per product. Stock and price belong
// to a store and are the same for every role there; cost is never cached (it's
// role-dependent, and shouldn't sit on the device). The cache outlives an app
// restart (sessions don't), so the next login may be at another store.

/// Which store the cached rows were saved for.
public struct ProductCacheScope: Equatable, Sendable {
    public let locationId: String

    public init(locationId: String) {
        self.locationId = locationId
    }

    /// Stored next to the cache (SyncMetadata). Its format differs from any older
    /// rule's key, so a cache saved under one (which may hold costs) is cleared.
    public var key: String { "store:\(locationId)" }

    /// Rows saved for another store, or for an unknown scope (an older cache),
    /// must not be shown.
    public func needsClear(storedKey: String?) -> Bool {
        storedKey != key
    }
}

/// Rows the server no longer lists (deleted, another store's one-store product)
/// stay cached forever unless swept after a full catalog walk.
public enum CacheSweep {
    /// Only after the warm-up reached the last page: a walk cut short by an error
    /// or cancellation never touched the rest, which are still good.
    public static func isStale(lastFetchedAt: Date, walkStartedAt: Date, walkCompleted: Bool) -> Bool {
        walkCompleted && lastFetchedAt < walkStartedAt
    }
}

/// The barcode scanner's on-device lookup. Several products can share a barcode
/// (presentations of one medication): opening one of them would be a guess.
public enum BarcodeLookup {
    public enum CacheDecision: Equatable, Sendable {
        case open
        /// The server's exact search shows every match to choose from.
        case askServer
    }

    public static func cacheDecision(matchCount: Int) -> CacheDecision {
        matchCount == 1 ? .open : .askServer
    }
}
