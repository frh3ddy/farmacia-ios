import Foundation

// MARK: - Scan Flow
//
// What scanning on Productos is for (tasks/scan-modes-epic.md): Consultar opens
// the product; Recibir and Contar open its receive / count form and come back to
// the scanner for the next item.

public enum ScanMode: String, CaseIterable, Sendable {
    case consult, receive, count

    /// The saved choice, or Consultar for an employee who can't receive or count.
    public static func effective(saved: ScanMode?, canManageInventory: Bool) -> ScanMode {
        canManageInventory ? saved ?? .consult : .consult
    }

    /// Nuevo producto from the scanner: Recibir's form asks for quantity, cost and supplier itself;
    /// Contar needs them on creation, or the typed cost is dropped and the count asks again.
    public var createShowsInitialStock: Bool { self != .receive }
}

/// What just happened in the scan flow.
public enum ScanEvent: Equatable, Sendable {
    /// One product matched the code, or one was picked from several.
    case matched
    case severalMatched
    case unknown
    /// Nuevo Producto saved, and the server returned the product.
    case created
    /// A form or the choose list closed with nothing to show next: saved,
    /// cancelled, or a create queued offline.
    case closed
}

/// Where the scan flow goes next.
public enum ScanNext: Equatable, Sendable {
    case openDetail, receive, count, choose, create, scan, close

    public static func after(_ event: ScanEvent, in mode: ScanMode) -> ScanNext {
        switch event {
        case .severalMatched: .choose
        case .unknown: .create
        // Consultar closes (as before); the runs scan the next item.
        case .closed: mode == .consult ? .close : .scan
        case .matched, .created:
            switch mode {
            case .consult: .openDetail
            case .receive: .receive
            case .count: .count
            }
        }
    }
}

/// The last receive or count saved from the scanner: the strip under the
/// viewfinder, and a note when the same product is scanned again right after.
public struct RecentScanSave: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case received(Int)
        /// `before`: the live stock the count was compared to, when it loaded.
        case counted(before: Int?, counted: Int)
    }

    public let productId: String
    public let name: String
    public let kind: Kind

    public init(productId: String, name: String, kind: Kind) {
        self.productId = productId
        self.name = name
        self.kind = kind
    }

    public var text: String { "\(name) · \(detail)" }

    private var detail: String {
        switch kind {
        case .received(let quantity):
            return "+\(Self.units(quantity))"
        case .counted(let before?, let counted):
            return StockImpact(before: before, change: counted - before)?.summary ?? "\(counted), sin cambios"
        case .counted(nil, let counted):
            return "contados: \(counted)"
        }
    }

    private var mode: ScanMode {
        if case .received = kind { return .receive }
        return .count
    }

    /// A non-blocking reminder (a second lot or a recount is fine); nil when it isn't a repeat.
    public func repeatNote(productId: String, mode: ScanMode) -> String? {
        guard productId == self.productId, mode == self.mode else { return nil }
        switch kind {
        case .received(let quantity): return "Ya recibiste \(Self.units(quantity)) de este producto hace un momento."
        case .counted: return "Ya contaste este producto hace un momento."
        }
    }

    private static func units(_ quantity: Int) -> String {
        quantity == 1 ? "1 ud" : "\(quantity) uds"
    }
}
