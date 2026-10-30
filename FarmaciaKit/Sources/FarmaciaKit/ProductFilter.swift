import Foundation

// MARK: - Product Filter
//
// The chips over the product list. En Riesgo (cash tied up in old stock) and
// Margen Bajo come from cost, so cashiers don't get them; Por Vencer they do.
// En Riesgo / Por Vencer filter by ids loaded separately (`RiskSet`); when that
// load failed, the empty list says so instead of "no results".

public enum ProductFilter: String, CaseIterable, Sendable {
    case all = "Todos"
    case lowStock = "Stock Bajo"
    case outOfStock = "Sin Stock"
    case inStock = "In Stock"
    case atRisk = "En Riesgo"
    case expiringSoon = "Por Vencer"
    case lowMargin = "Margen Bajo"

    public static func visible(canViewCosts: Bool) -> [ProductFilter] {
        canViewCosts ? allCases : allCases.filter { $0 != .atRisk && $0 != .lowMargin }
    }

    /// The empty-list text for this filter, given the state of its risk ids.
    public func emptyState(risk: RiskSet) -> (title: String, message: String) {
        if (self == .atRisk || self == .expiringSoon) && risk == .unavailable {
            return ("No Disponible", "No se pudo cargar qué productos están \(self == .atRisk ? "en riesgo" : "por vencer"). Desliza hacia abajo para reintentar.")
        }
        return ("Sin Resultados", "Ningún producto coincide con tu búsqueda o filtro.")
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
