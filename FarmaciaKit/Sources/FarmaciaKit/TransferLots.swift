import Foundation

// MARK: - Transfer lots ("Caducidades aquí")
//
// The product sheet lists this store's lots from GET /inventory/lots (`CurrentLot`),
// soonest expiry first. It's what the store has, not what a send takes: FIFO sends the
// first received (tasks/transfers-review-followups-epic.md §1 has the preview for that).

public enum TransferLots {
    public struct Row: Equatable, Sendable {
        public let text: String
        public let tone: Tone

        public init(text: String, tone: Tone) {
            self.text = text
            self.tone = tone
        }
    }

    /// `onHand`: the store's stock. The endpoint skips lots with neither expiry nor lot
    /// number, so whatever the lots don't cover is "sin caducidad registrada".
    public static func rows(_ lots: [CurrentLot], onHand: Int?, now: Date = Date(),
                            timeZone: TimeZone = .current) -> [Row] {
        let sorted = lots.sorted { ($0.expiryDate ?? "9999") < ($1.expiryDate ?? "9999") }
        var rows = sorted.map { row(for: $0, now: now, timeZone: timeZone) }
        let uncovered = (onHand ?? 0) - lots.reduce(0) { $0 + $1.quantity }
        if uncovered > 0 { rows.append(Row(text: "\(uncovered) sin caducidad registrada", tone: .neutral)) }
        return rows
    }

    private static func row(for lot: CurrentLot, now: Date, timeZone: TimeZone) -> Row {
        let lotText = lot.batchNumber.map { $0.isEmpty ? "" : " · lote \($0)" } ?? ""
        guard let day = lot.expiryDate.flatMap(utcDay) else {
            return Row(text: "\(lot.quantity) · sin caducidad\(lotText)", tone: .neutral)
        }
        let days = Expiry.daysUntil(day, now: now, timeZone: timeZone)
        let verb = days <= 0 ? "venció" : "vence"
        return Row(text: "\(lot.quantity) · \(verb) \(Expiry.display(day))\(lotText)", tone: Expiry.tone(daysUntil: days))
    }

    /// "YYYY-MM-DD" as that calendar day in UTC, which is how `Expiry` reads a lot's day.
    private static func utcDay(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
