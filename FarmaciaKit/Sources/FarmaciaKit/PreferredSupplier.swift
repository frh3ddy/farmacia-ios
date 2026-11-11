import Foundation

// MARK: - Preferred Supplier
//
// The receive form auto-picks a supplier. It needs two lists that load
// separately (the product's suppliers, and all suppliers to pick from), so the
// form asks again whenever either arrives.
// Which one: the scanner run's choice (Recibir › "Recibiendo de") if one was
// made, else the product's preferred one (tasks/receiving-run-supplier-epic.md).

/// Recibir's "Recibiendo de" for a scan run.
public enum RunSupplier: Equatable, Sendable {
    /// Nothing chosen: each form takes the product's preferred supplier.
    case unset
    /// "Sin proveedor" chosen: every form starts on none.
    case noSupplier
    case supplier(String)

    /// From the picker, where "Sin proveedor" and nothing picked are both a nil supplier.
    public init(chosen: Bool, id: String?) {
        guard chosen else { self = .unset; return }
        self = id.map(Self.supplier) ?? .noSupplier
    }
}

public enum PreferredSupplier {
    /// The supplier to select, or nil to leave the selection alone: nothing to
    /// pick (or the run is "Sin proveedor"), the user already chose one, or the
    /// one to pick isn't in the list yet (the preferred one doesn't stand in for
    /// a run supplier: the next load picks it).
    public static func pick(run: RunSupplier = .unset, preferredId: String?,
                            selectedId: String?, available: [String]) -> String? {
        let id: String?
        switch run {
        case .unset: id = preferredId
        case .noSupplier: id = nil
        case .supplier(let runId): id = runId
        }
        guard selectedId == nil, let id, available.contains(id) else { return nil }
        return id
    }
}
