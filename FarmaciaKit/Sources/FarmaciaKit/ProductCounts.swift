import Foundation

/// Server-computed catalog counts (GET /products/counts).
/// Covers ALL products at the location — unlike a paginated list fetch.
public struct ProductCountsResponse: Decodable, Sendable {
    public let total: Int
    public let outOfStock: Int
    public let lowStock: Int
    /// Absent for a cashier: it's worked out from cost, which a cashier never sees.
    public let lowMargin: Int?
    public let synced: Int
    public let local: Int
}

extension ProductCountsResponse {
    /// The Products stats row. Both numbers come from these counts (stocked, not
    /// discontinued); the list's total also has discontinued and untracked items,
    /// so setting it next to `synced` made products look unsynced. No counts, no row:
    /// an estimate from the loaded page would undercount.
    public static func syncSummary(_ counts: ProductCountsResponse?, locale: Locale = .current) -> String? {
        guard let counts else { return nil }
        let synced = counts.synced.formatted(.number.locale(locale))
        let total = counts.total.formatted(.number.locale(locale))
        return "\(synced) de \(total) sincronizados con Square"
    }
}
