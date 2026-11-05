import Foundation

// MARK: - Conteo inicial
//
// A store-wide recount of the stock the migration loaded (tasks/opening-count-epic.md).
// While a session is open, counts at the store go to it instead of Corrección de Conteo.

/// The store's open Conteo inicial (`GET /inventory/stock-counts/active`).
public struct StockCountSession: Decodable, Equatable, Sendable {
    public let id: String
    public let startedAt: Date
    public let countedProducts: Int

    /// An API from before Conteo inicial answers the active-count read with 404: no count can be
    /// open there, so counts go on as Corrección de Conteo instead of being blocked.
    public static func noCountOnServer(_ error: Error) -> Bool {
        if case NetworkError.httpError(statusCode: 404, _) = error { return true }
        return false
    }
}

/// What Guardar does with a count.
public enum CountSave: Equatable, Sendable {
    case save, closeWithoutSaving

    /// A count equal to the stock is saved in a Conteo inicial: that's how the
    /// product counts as counted. A correction has nothing to save.
    public static func action(matches: Bool, inOpeningCount: Bool) -> CountSave {
        matches && !inOpeningCount ? .closeWithoutSaving : .save
    }
}

/// A product with stock at the store that the session hasn't counted (`GET /inventory/stock-counts/:id/uncounted`).
public struct UncountedProduct: Decodable, Identifiable, Equatable, Sendable {
    public var id: String { productId }
    public let productId: String
    public let name: String
    public let units: Int
    /// Value at cost, a decimal string.
    public let value: String

    public init(productId: String, name: String, units: Int, value: String) {
        self.productId = productId
        self.name = name
        self.units = units
        self.value = value
    }
}

/// "3 productos · 8 unidades · $80.00", for the "Poner todos en 0" confirmation.
public struct UncountedSummary: Equatable, Sendable {
    public let products: Int
    public let units: Int
    public let value: Decimal

    public init(_ rows: [UncountedProduct]) {
        products = rows.count
        units = rows.reduce(0) { $0 + $1.units }
        value = rows.reduce(Decimal(0)) { $0 + (Decimal(string: $1.value, locale: Locale(identifier: "en_US_POSIX")) ?? 0) }
    }

    public var text: String {
        [
            products == 1 ? "1 producto" : "\(products) productos",
            units == 1 ? "1 unidad" : "\(units) unidades",
            ReportFormat.currency("\(value)"),
        ].joined(separator: " · ")
    }
}

/// `POST /inventory/stock-counts/:id/entries`: the shelf total; the server derives the change.
public struct StockCountEntryRequest: Encodable, Sendable {
    public let productId: String
    public let countedQuantity: Int
    public let unitCost: Double?
    /// The form's, kept across retries: a retry after the count committed returns the first result.
    public let clientRequestId: String

    public init(productId: String, countedQuantity: Int, unitCost: Double?, clientRequestId: String) {
        self.productId = productId
        self.countedQuantity = countedQuantity
        self.unitCost = unitCost
        self.clientRequestId = clientRequestId
    }
}

/// `POST /inventory/stock-counts/:id/zero`.
public struct StockCountZeroRequest: Encodable, Sendable {
    public let productIds: [String]
    public init(productIds: [String]) { self.productIds = productIds }
}

/// One product of a "Poner en 0" run.
public struct StockCountZeroResult: Decodable, Sendable {
    public let productId: String
    public let ok: Bool
    /// "ALREADY_COUNTED": counted after the list loaded, so it was left alone.
    public let code: String?
    public let error: String?

    var wasSkipped: Bool { code == "ALREADY_COUNTED" }
}

/// What to tell the owner after "Poner en 0": nil when every product went to 0.
/// A product counted meanwhile was skipped on purpose, so it isn't reported as a failure.
public struct ZeroOutcome: Sendable {
    public let message: String?

    /// `stoppedBy`: why a batch failed, ending the run; the rest stay on the list.
    public init(_ results: [StockCountZeroResult], stoppedBy: String? = nil) {
        let failed = results.filter { !$0.ok && !$0.wasSkipped }
        let skipped = results.filter(\.wasSkipped).count
        var lines: [String] = []
        if let first = failed.first {
            let who = failed.count == 1 ? "1 producto no se pudo" : "\(failed.count) productos no se pudieron"
            lines.append("\(who) poner en 0: \(first.error ?? "error desconocido")")
        }
        if skipped > 0 {
            lines.append(skipped == 1
                ? "1 producto ya se había contado; se dejó como estaba."
                : "\(skipped) productos ya se habían contado; se dejaron como estaban.")
        }
        if let stoppedBy {
            lines.append("Se detuvo: \(stoppedBy). Los que faltan siguen en la lista.")
        }
        message = lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

/// "Poner todos en 0" in batches: the API zeroes one product at a time (with a Square call each),
/// so a whole store in one request would outlast the client's timeout while the server kept going.
public enum ZeroBatch {
    public static let size = 25 // ~1s per Square call keeps a batch well under the 60s timeout

    public static func split(_ productIds: [String]) -> [[String]] {
        stride(from: 0, to: productIds.count, by: size).map { Array(productIds[$0..<min($0 + size, productIds.count)]) }
    }
}

/// The part of `POST /inventory/stock-counts/:id/entries` the app reads back.
public struct StockCountEntryResult: Decodable, Sendable {
    public struct Sync: Decodable, Sendable {
        public let synced: Bool
        public let error: String?
    }

    /// Present only when the count changed the stock (a match or a replay sends nothing to Square).
    public let squareSync: Sync?

    /// Said after the save when Square didn't take the change, so the shelf and Square don't drift unnoticed.
    public var squareWarning: String? {
        guard let squareSync, !squareSync.synced else { return nil }
        let reason = squareSync.error.map { ": \($0)" } ?? ""
        return "Conteo guardado, pero no se sincronizó con Square\(reason). Puedes reintentar desde el historial."
    }
}
