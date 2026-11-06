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

    /// Guardar is enabled: a count that changes the stock, or, in a Conteo inicial, one that matches it.
    public static func canSave(change: Int?, matches: Bool, inOpeningCount: Bool) -> Bool {
        change != nil || (inOpeningCount && matches)
    }

    /// Where the count's stepper starts: the stock once it loads, so counting is ± from it;
    /// a number already typed is never overwritten by a (re)load.
    public static func startValue(liveStock: Int?, typed: Int?) -> Int? {
        typed ?? liveStock
    }

    /// The one-tap "Sin cambios" of a Conteo inicial: the stock to save as the count, once it has loaded.
    public static func quickMatch(liveStock: Int?, inOpeningCount: Bool) -> Int? {
        inOpeningCount ? liveStock : nil
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
    /// The counted lots (Conteo inicial); nil leaves the product's lots as they are.
    public let lots: [StockCountLot]?
    /// The store the form shows, so the count never lands on the session's store if they differ.
    public let locationId: String?
    /// Razón and Notas, trimmed; blank ones are left out.
    public let reason: String?
    public let notes: String?

    public init(productId: String, countedQuantity: Int, unitCost: Double?, clientRequestId: String,
                lots: [StockCountLot]? = nil, locationId: String? = nil, reason: String? = nil, notes: String? = nil) {
        self.productId = productId
        self.countedQuantity = countedQuantity
        self.unitCost = unitCost
        self.clientRequestId = clientRequestId
        self.lots = lots
        self.locationId = locationId
        self.reason = Self.text(reason)
        self.notes = Self.text(notes)
    }

    private static func text(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

/// Razón and Notas within the API's limit (it refuses more with a 400), checked before Guardar.
public enum CountNotes {
    public static let maxLength = 500

    public static func problem(reason: String, notes: String) -> String? {
        let tooLong = [reason, notes].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).count > maxLength }
        return tooLong ? "La razón y las notas deben tener \(maxLength) caracteres o menos" : nil
    }
}

/// `POST /inventory/stock-counts/:id/zero`.
public struct StockCountZeroRequest: Encodable, Sendable {
    public let productIds: [String]
    public let locationId: String?
    public init(productIds: [String], locationId: String? = nil) {
        self.productIds = productIds
        self.locationId = locationId
    }
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

// MARK: - Lots in a Conteo inicial
//
// Optional rows of quantity + caducidad (month) + lote. When any is entered they can't add up to more
// than the count (the rest stays without lot info); the API then replaces the product's lots at the store with them (tasks/opening-count-lots-epic.md).

public struct CountLot: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var quantity: Int?
    public var expiry: MonthYear?
    public var batchNumber: String

    public init(id: UUID = UUID(), quantity: Int? = nil, expiry: MonthYear? = nil, batchNumber: String = "") {
        self.id = id
        self.quantity = quantity
        self.expiry = expiry
        self.batchNumber = batchNumber
    }

    private var lot: String { batchNumber.trimmingCharacters(in: .whitespaces) }

    /// No units: ignored, so a lot the split left at 0 (or an empty row) never blocks Guardar.
    /// A new "Agregar lote" row takes its share of the count, so it needs its caducidad; deleting it gives the share back.
    public var isBlank: Bool { (quantity ?? 0) == 0 }

    /// The row after a camera scan of the box: what the scan read replaces the field, what it
    /// missed keeps what was there; the quantity stays.
    public func applying(_ scan: LotScan) -> CountLot {
        var row = self
        if let lot = scan.lot { row.batchNumber = lot }
        if let expiry = scan.expiry { row.expiry = expiry }
        return row
    }

    /// Under a row with details but no units: such a row is ignored (`isBlank`), so it isn't saved.
    public var ignoredHint: String? {
        isBlank && (expiry != nil || !lot.isEmpty) ? "Sin cantidad: este lote no se guardará" : nil
    }

    /// The caducidad is what matters; the lote number is optional.
    public var isComplete: Bool { (quantity ?? 0) > 0 && expiry != nil }
}

/// The count form's lot rows and when the count is spread over them (`CountLots.split`).
/// The view forwards user events only: setting the count programmatically (the stock loading,
/// "Sin cambios") isn't an event, so pre-filled lots stay as they are.
public struct LotSplit: Sendable {
    public var rows: [CountLot]
    /// Rows whose quantity was changed by hand: a split leaves them as they are.
    private var edited: Set<UUID> = []

    public init(_ rows: [CountLot] = []) { self.rows = rows }

    /// The product's current lots. They keep their quantities when the count changes (they're what
    /// the store knows about its caducidades), except a single lot that is the whole stock: it
    /// follows the count. Lots the counter adds share whatever the pre-filled ones don't cover.
    public init(prefilled rows: [CountLot], stock: Int?) {
        self.rows = rows
        let followsCount = rows.count == 1 && rows[0].quantity == stock
        if !followsCount { edited = Set(rows.map(\.id)) }
    }

    /// The counter changed the count. A field echoing the same value back is no change.
    public mutating func countChanged(from old: Int?, to new: Int?) {
        guard old != new else { return }
        split(new)
    }

    /// A quantity typed or ±'d on a row. The field writing back what it shows doesn't pin it.
    public mutating func setQuantity(_ quantity: Int?, of id: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == id }), rows[index].quantity != quantity else { return }
        rows[index].quantity = quantity
        edited.insert(id)
    }

    public mutating func add(_ row: CountLot, count: Int?) {
        rows.append(row)
        split(count)
    }

    public mutating func remove(atOffsets offsets: IndexSet, count: Int?) {
        for index in offsets.sorted(by: >) { edited.remove(rows.remove(at: index).id) }
        split(count)
    }

    private mutating func split(_ count: Int?) {
        rows = CountLots.split(count, across: rows, keeping: edited)
    }
}

/// When the count form reads the product's lots: once per store and Conteo inicial, so a reload
/// (connection back) keeps what was edited, while another store or count never shows stale lots.
public struct CountLotsLoad: Equatable, Sendable {
    private var loadedFor: String?

    public init() {}

    private static func key(_ locationId: String, _ session: StockCountSession?) -> String? {
        session.map { "\(locationId)|\($0.id)" }
    }

    public func needsLoad(locationId: String, session: StockCountSession?) -> Bool {
        guard let key = Self.key(locationId, session) else { return false }
        return key != loadedFor
    }

    /// The lots section shows, and its lots are sent, only for the store and count they were read for.
    public func isAvailable(locationId: String, session: StockCountSession?) -> Bool {
        guard let key = Self.key(locationId, session) else { return false }
        return key == loadedFor
    }

    public mutating func loaded(locationId: String, session: StockCountSession?) {
        loadedFor = Self.key(locationId, session)
    }
}

/// A lot as `POST …/entries` takes it: `expiryDate` (always set; lote optional) like receiving (`LocalDay` of the month's first day).
public struct StockCountLot: Encodable, Equatable, Sendable {
    public let quantity: Int
    public let expiryDate: String?
    public let batchNumber: String?
}

public enum LotsCheck: Equatable, Sendable {
    /// No lots entered: the count saves on its own.
    case none
    case matches
    /// Lots under the count: allowed, the rest stays without lot info ("3 unidades sin lote", a hint).
    case partial(String)
    /// Blocks Guardar: lots over the count, or a lot missing its caducidad and lote.
    case mismatch(String)
}

public struct CountLots: Sendable {
    public let rows: [CountLot]
    /// The rows pre-filled from the product's current lots. Left untouched, they're neither checked
    /// nor sent, so the product's lots stay as they are (stock without lot info can't block a save).
    public let original: [CountLot]

    public init(_ rows: [CountLot], original: [CountLot] = []) {
        self.rows = rows
        self.original = original
    }

    /// The API's cap on lots in one count (a 400 past it).
    public static let maxLots = 50

    /// "Agregar lote" / "Escanear caja" stay available while there's room.
    public static func canAdd(to rows: [CountLot]) -> Bool { rows.count < maxLots }

    private var untouched: Bool { rows == original }

    private var entered: [CountLot] { untouched ? [] : rows.filter { !$0.isBlank } }

    public func check(counted: Int?) -> LotsCheck {
        let entered = entered
        guard !entered.isEmpty else { return .none }
        if entered.count > Self.maxLots {
            return .mismatch("Un conteo puede tener como máximo \(Self.maxLots) lotes")
        }
        let total = entered.reduce(0) { $0 + ($1.quantity ?? 0) }
        let counted = counted ?? 0
        if total > counted {
            return .mismatch("Los lotes suman \(total) de \(counted): sobran \(total - counted)")
        }
        guard entered.allSatisfy(\.isComplete) else {
            return .mismatch("Cada lote necesita su caducidad")
        }
        guard total != counted else { return .matches }
        guard total > counted else {
            let rest = counted - total
            return .partial(rest == 1 ? "1 unidad sin lote" : "\(rest) unidades sin lote")
        }
        return .mismatch("Los lotes suman \(total) de \(counted): sobran \(total - counted)")
    }

    /// The count spread over the lot rows: one row takes it all, several split it evenly (the
    /// remainder to the first rows), so the lots add up to the count before any ± on a row.
    /// Rows in `keeping` (edited by hand) stay as they are; the rest of the count goes to the others.
    /// No count or no rows to fill: unchanged.
    public static func split(_ counted: Int?, across rows: [CountLot], keeping: Set<UUID> = []) -> [CountLot] {
        let open = rows.filter { !keeping.contains($0.id) }
        guard let counted, !open.isEmpty else { return rows }
        let kept = rows.filter { keeping.contains($0.id) }.reduce(0) { $0 + ($1.quantity ?? 0) }
        let (share, extra) = max(0, counted - kept).quotientAndRemainder(dividingBy: open.count)
        var index = 0
        return rows.map { row in
            guard !keeping.contains(row.id) else { return row }
            var row = row
            row.quantity = share + (index < extra ? 1 : 0)
            index += 1
            return row
        }
    }

    /// What keeps "Sin cambios" from saving: edited lots over the stock (or a lot missing its details).
    public func quickMatchBlocker(stock: Int) -> String? {
        if case .mismatch(let reason) = check(counted: stock) { return reason }
        return nil
    }

    /// The lots to send, or nil when none were entered (the key is left out, so lots stay as they are).
    public func requestLots(timeZone: TimeZone = .current) -> [StockCountLot]? {
        let entered = entered
        guard !entered.isEmpty else { return nil }
        return entered.map { row in
            let lot = row.batchNumber.trimmingCharacters(in: .whitespaces)
            return StockCountLot(
                quantity: row.quantity ?? 0,
                expiryDate: row.expiry.map { LocalDay.string(from: $0.firstDay(timeZone: timeZone), timeZone: timeZone) },
                batchNumber: lot.isEmpty ? nil : lot
            )
        }
    }
}

/// A lot the product has now at the store (`GET /inventory/lots`), to pre-fill the count's rows.
public struct CurrentLot: Decodable, Sendable {
    public let quantity: Int
    /// A calendar day, "YYYY-MM-DD".
    public let expiryDate: String?
    public let batchNumber: String?

    public var row: CountLot {
        CountLot(quantity: quantity, expiry: expiryDate.flatMap(Self.month), batchNumber: batchNumber ?? "")
    }

    /// The day is a calendar string, so its year and month are read straight off it (no time-zone math).
    private static func month(_ day: String) -> MonthYear? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return nil }
        return MonthYear(year: parts[0], month: parts[1])
    }
}

/// A product already counted in the open Conteo inicial (`GET …/entries?productId=`), so a recount
/// across days is a choice, not a surprise.
public struct CountedEntry: Decodable, Equatable, Sendable {
    public let countedQuantity: Int
    public let countedAt: Date
    public let countedByName: String?
    /// The earlier count's Razón and Notas (absent on servers from before them).
    public let reason: String?
    public let notes: String?

    /// "Caja rota · en bodega" under the "Ya contado" line; nil when there are none.
    public var remarks: String? {
        let parts = [reason, notes].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Ya contado en este conteo: 10 · 5 nov, Fredy", the day in the store's time zone.
    public func note(timeZone: TimeZone = .current, locale: Locale = Locale(identifier: "es_MX")) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, timeZone: timeZone)
            .day().month(.abbreviated)
        style.timeZone = timeZone
        let day = countedAt.formatted(style).replacingOccurrences(of: ".", with: "")
        let who = countedByName.map { ", \($0)" } ?? ""
        return "Ya contado en este conteo: \(countedQuantity) · \(day)\(who)"
    }
}
