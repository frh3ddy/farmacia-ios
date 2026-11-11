import Foundation

// MARK: - Product Filter
//
// The chips over the product list; the server filters (GET /products?filter=),
// so a filtered list holds every match, not just the pages already loaded.
// En Riesgo (cash tied up in old stock) and Margen Bajo come from cost, so
// cashiers don't get them; Por Vencer they do. The En Riesgo / Por Vencer chip
// counts come from the aging ids (`RiskSet`), "—" when those failed to load.
// Pausados shows only when the server counts paused products (a server
// without stock alerts doesn't know the filter).

public enum ProductFilter: String, CaseIterable, Sendable {
    case all = "Todos"
    case lowStock = "Stock Bajo"
    case outOfStock = "Sin Stock"
    case inStock = "In Stock"
    case atRisk = "En Riesgo"
    case expiringSoon = "Por Vencer"
    case lowMargin = "Margen Bajo"
    case paused = "Pausados"

    /// The `filter` query value for GET /products; nil for Todos.
    public var apiValue: String? {
        switch self {
        case .all: return nil
        case .lowStock: return "lowStock"
        case .outOfStock: return "outOfStock"
        case .inStock: return "inStock"
        case .atRisk: return "atRisk"
        case .expiringSoon: return "expiring"
        case .lowMargin: return "lowMargin"
        case .paused: return "paused"
        }
    }

    /// The chip's color by meaning (the app maps tones to colors).
    public var tone: Tone {
        switch self {
        case .all: .info
        case .outOfStock, .atRisk: .critical
        case .lowStock, .expiringSoon, .lowMargin: .caution
        case .inStock: .positive
        case .paused: .neutral
        }
    }

    public static func visible(canViewCosts: Bool, showsPaused: Bool = false) -> [ProductFilter] {
        allCases.filter { filter in
            switch filter {
            case .atRisk, .lowMargin: canViewCosts
            case .paused: showsPaused
            default: true
            }
        }
    }

    /// `filter` if the role may use it, else Todos (e.g. after switching to a store
    /// where this employee is a cashier).
    public static func coerced(_ filter: ProductFilter, canViewCosts: Bool, showsPaused: Bool = false) -> ProductFilter {
        visible(canViewCosts: canViewCosts, showsPaused: showsPaused).contains(filter) ? filter : .all
    }
}

/// Product ids for the En Riesgo / Por Vencer chips, and whether they loaded.
public enum RiskSet: Equatable, Sendable {
    case loading
    case loaded(Set<String>)
    case unavailable

    public var ids: Set<String> {
        if case .loaded(let ids) = self { return ids }
        return []
    }

    /// The chip badge; nil when there's no number to show.
    public var count: Int? {
        if case .loaded(let ids) = self { return ids.count }
        return nil
    }

    /// The state after a failed load: unchanged if it was only cancelled.
    public func after(failure error: Error) -> RiskSet {
        NetworkError.isCancellation(error) ? self : .unavailable
    }
}
