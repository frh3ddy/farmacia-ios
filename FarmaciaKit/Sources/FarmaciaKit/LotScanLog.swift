import Foundation

// MARK: - Lot Scan Log
//
// The lot bench's rows (`LotScanMetrics`, DEBUG) and which one filled the form last, so the
// form's save can mark it edited or not. Only the latest opening counts: a give-up, or a form
// closed without saving, forgets the fill, so typed values never mark an older read.

public struct LotScanLog: Codable, Sendable {
    public private(set) var rows: [LotScanMetrics] = []
    private var lastFilled: Int?

    public init() {}

    public mutating func log(_ row: LotScanMetrics) {
        rows.append(row)
        lastFilled = row.lot != nil || row.expiry != nil ? rows.count - 1 : nil
    }

    /// The form was saved with these values.
    public mutating func saved(lot: String?, expiry: MonthYear?) {
        guard let index = lastFilled, rows.indices.contains(index) else { return }
        rows[index].recordSave(lot: lot, expiry: expiry)
        lastFilled = nil
    }

    /// The form closed without saving.
    public mutating func formClosed() { lastFilled = nil }

    public mutating func clear() { self = LotScanLog() }
}
