import Foundation

// MARK: - Transfer draft store
//
// The Transferencias list stays on the phone until it's sent or cleared: one per
// employee and store (its stock numbers are the sending store's). The request id
// is saved with it, so a resend after a restart can't ship twice.
// tasks/transfer-list-persist-epic.md

public enum TransferDraftStore {
    /// Nil without an employee or a store (logout clears the store first): nothing to load or save.
    public static func key(employeeId: String?, locationId: String?) -> String? {
        guard let employeeId, let locationId else { return nil }
        return "transferDraft.\(employeeId).\(locationId)"
    }

    /// The saved list, or an empty one when there's none. Throws when it can't be
    /// read, so the screen can say the list was lost.
    public static func load(_ defaults: UserDefaults, key: String) throws -> TransferDraft {
        guard let data = defaults.data(forKey: key) else { return TransferDraft() }
        return try JSONDecoder().decode(TransferDraft.self, from: data)
    }

    /// A saved list that isn't on screen: Enviar finished after a store switch, so its
    /// outcome goes to the list it sent. Unreadable data is left alone.
    public static func update(_ defaults: UserDefaults, key: String, _ change: (inout TransferDraft) -> Void) {
        guard var draft = try? load(defaults, key: key) else { return }
        change(&draft)
        save(draft, to: defaults, key: key)
    }

    /// An empty list (sent or cleared) removes the saved one.
    public static func save(_ draft: TransferDraft, to defaults: UserDefaults, key: String) {
        guard !draft.lines.isEmpty, let data = try? JSONEncoder().encode(draft) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}

/// POST /transfers/stock: this store's stock for the listed products, in one call
/// (farmacia-ops feature/transfer-stock-endpoint). Answers `{ data: { productId: Int } }`.
public struct TransferStockRequest: Encodable, Equatable, Sendable {
    public let locationId: String
    public let productIds: [String]
}

public extension TransferDraft {
    /// Nil with no lines. The server takes 100 ids at most; a longer list can't be sent anyway.
    func stockRequest(locationId: String) -> TransferStockRequest? {
        guard !lines.isEmpty else { return nil }
        return TransferStockRequest(locationId: locationId, productIds: lines.prefix(Self.maxItems).map(\.productId))
    }
}

/// A line whose stock changed since it was added (TransferDraft.refreshAvailable).
public struct TransferStockChange: Equatable, Sendable {
    public let name: String
    public let before: Int
    public let after: Int

    public init(name: String, before: Int, after: Int) {
        self.name = name
        self.before = before
        self.after = after
    }

    /// "Cambiaron las existencias: Paracetamol 10 → 4", three at most then "y N más"; nil with none.
    public static func notice(_ changes: [TransferStockChange]) -> String? {
        guard !changes.isEmpty else { return nil }
        let shown = changes.prefix(3).map { "\($0.name) \($0.before) → \($0.after)" }.joined(separator: ", ")
        let more = changes.count > 3 ? " y \(changes.count - 3) más" : ""
        return "Cambiaron las existencias: \(shown)\(more)"
    }
}
