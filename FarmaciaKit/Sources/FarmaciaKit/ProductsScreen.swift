import Foundation

// MARK: - Products Screen
//
// Productos is search-first: staff search or scan, they never scroll the catalog.
// With no search and no chip it shows the products opened recently on this phone
// and loads no list; a chip opens its short server list; Todos ("Ver todo") is the
// full catalog, for rare needs like a shelf count.

public enum ProductsScreen {
    /// The list to load; nil on the start screen (recents) or before a store is set.
    public static func query(locationId: String?, search: String, filter: ProductFilter?) -> ProductListQuery? {
        guard let locationId else { return nil }
        let query = ProductListQuery(locationId: locationId, search: search, filter: filter)
        return query.search == nil && filter == nil ? nil : query
    }
}

extension ProductFilter {
    /// The chips under the search field: the short lists only, most urgent first.
    public static func chips(canViewCosts: Bool, showsPaused: Bool) -> [ProductFilter] {
        let visible = visible(canViewCosts: canViewCosts, showsPaused: showsPaused)
        return [.outOfStock, .lowStock, .expiringSoon, .paused, .atRisk, .lowMargin].filter(visible.contains)
    }
}

// MARK: - Recent Products

/// The products opened most recently on this phone, newest first.
public enum RecentProducts {
    public static func adding(_ id: String, to ids: [String], limit: Int = 10) -> [String] {
        Array(([id] + ids.filter { $0 != id }).prefix(limit))
    }

    /// `items` in recent order; ids no longer in the catalog are skipped.
    public static func ordered<T: Identifiable>(_ items: [T], by ids: [String]) -> [T] where T.ID == String {
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byId[$0] }
    }
}
