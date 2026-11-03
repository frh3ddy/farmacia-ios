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

    /// The scan flow's next step from the server's exact search.
    public enum ServerDecision: Equatable, Sendable {
        /// Open the (first) result.
        case open
        /// Several results: list them to choose from.
        case choose
        /// Nothing found (or the search failed): create a product with the code.
        case create
    }

    /// GTIN lengths (EAN-8, UPC-A, EAN-13, GTIN-14); leading zeros pad between them.
    private static let gtinLengths = [8, 12, 13, 14]

    /// Every SKU a scanned code may be saved under, the scanned one first: a GTIN's
    /// zero-padded forms (the iPhone can read an EAN-13 as 14 digits, and products
    /// were saved with either). Anything else is only itself.
    public static func codeVariants(_ code: String) -> [String] {
        guard gtinLengths.contains(code.count), code.allSatisfy(\.isASCIIDigit) else { return [code] }
        let core = code.drop(while: { $0 == "0" })
        let padded = gtinLengths
            .filter { $0 >= core.count }
            .map { String(repeating: "0", count: $0 - core.count) + core }
        return [code] + padded.filter { $0 != code }
    }

    /// The SKU a new product gets from a scan: the 14-digit form of an EAN-13 loses
    /// its leading zero, so it matches the box and Square's register scanner.
    public static func newProductSku(_ code: String) -> String {
        code.count == 14 && code.hasPrefix("0") && code.allSatisfy(\.isASCIIDigit) ? String(code.dropFirst()) : code
    }

    public static func serverDecision(exactMatch: Bool?, resultCount: Int) -> ServerDecision {
        if exactMatch == true, resultCount > 0 { return .open }
        switch resultCount {
        case 0: return .create
        case 1: return .open
        default: return .choose
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
