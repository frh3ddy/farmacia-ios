import Foundation

// MARK: - Product Delta Sync
//
// GET /products/sync returns the store's products changed since an opaque cursor
// (none: everything), products removed since, the next cursor and hasMore.
// The phone keeps the cursor next to the cache and saves both together, only
// after the last page: a walk cut short keeps the old cursor and starts again
// from it (re-sent rows are harmless).

public struct ProductSyncPage<Row: Sendable>: Sendable {
    public let rows: [Row]
    public let removedIds: [String]
    public let cursor: String
    public let hasMore: Bool

    public init(rows: [Row], removedIds: [String], cursor: String, hasMore: Bool) {
        self.rows = rows
        self.removedIds = removedIds
        self.cursor = cursor
        self.hasMore = hasMore
    }
}

/// What a finished sync writes to the cache, all at once.
public struct ProductSyncResult<Row: Sendable>: Sendable {
    public let upserts: [Row]
    public let removedIds: Set<String>
    public let cursor: String
    /// Walked from no cursor: the cache becomes exactly `upserts`.
    public let isFullWalk: Bool
}

extension ProductSyncResult where Row: Identifiable, Row.ID == String {
    /// Cached rows to delete: the removed ones, and on a full walk every one it didn't
    /// return (products deleted before the server recorded removals have no mark).
    public func idsToDelete(cached: Set<String>) -> Set<String> {
        guard isFullWalk else { return cached.intersection(removedIds) }
        return cached.subtracting(upserts.map(\.id))
    }
}

public enum ProductSync {
    /// Walks every page from the stored cursor (nil: a full walk). An id on several
    /// pages ends as its last appearance: changed, re-sent or removed. A cursor the
    /// server rejects (400) is dropped for a full walk; any other failure throws, and
    /// the caller keeps its stored cursor.
    public static func run<Row: Identifiable & Sendable>(
        from storedCursor: String?,
        fetch: (String?) async throws -> ProductSyncPage<Row>
    ) async throws -> ProductSyncResult<Row> where Row.ID == String {
        do {
            return try await walk(from: storedCursor, fetch: fetch)
        } catch NetworkError.httpError(statusCode: 400, _) where storedCursor != nil {
            return try await walk(from: nil, fetch: fetch)
        }
    }

    private static func walk<Row: Identifiable & Sendable>(
        from storedCursor: String?,
        fetch: (String?) async throws -> ProductSyncPage<Row>
    ) async throws -> ProductSyncResult<Row> where Row.ID == String {
        var upserts: [String: Row] = [:]
        var removed: Set<String> = []
        var cursor = storedCursor
        while true {
            let page = try await fetch(cursor)
            for row in page.rows {
                upserts[row.id] = row
                removed.remove(row.id)
            }
            for id in page.removedIds {
                upserts[id] = nil
                removed.insert(id)
            }
            cursor = page.cursor
            if !page.hasMore {
                return ProductSyncResult(upserts: Array(upserts.values), removedIds: removed,
                                         cursor: page.cursor, isFullWalk: storedCursor == nil)
            }
        }
    }
}
