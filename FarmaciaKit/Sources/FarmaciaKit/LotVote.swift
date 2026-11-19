import Foundation

// MARK: - Lot Vote
//
// The lab lot reader's answer over many passes (frames × image filters). The caducidad
// is what matters: by default it's taken from the first pass that reads one, like the
// live-text scanner (some boxes show it for a split second). `votesNeeded` stays a
// setting so the bench can raise it if misread dates show up. The lote is the one read
// most often so far (one pass misreads D26U908 as 026U908; the same misread rarely
// comes back as often).

public struct LotVote: Sendable {
    public let votesNeeded: Int
    /// Dates in the order first read, with how often each was read.
    private var dates: [(date: MonthYear, count: Int)] = []
    private var lots: [String: Int] = [:]

    private let today: MonthYear

    public init(today: MonthYear, votesNeeded: Int = 1) {
        self.today = today
        self.votesNeeded = max(votesNeeded, 1)
    }

    public mutating func add(_ scan: LotScan) {
        // A past date, or one further out than any medicine lasts, is a misread digit even
        // after "CAD" (a smudged "JUL ?7" read as JUL 17): never close the scanner on it.
        if let expiry = scan.expiry, !expiry.isBefore(today),
           expiry.months(since: today) <= ExpiryText.looseWindowMonths {
            if let i = dates.firstIndex(where: { $0.date == expiry }) { dates[i].count += 1 } else { dates.append((expiry, 1)) }
        }
        if let lot = scan.lot { lots[lot, default: 0] += 1 }
    }

    /// The date read most often (a tie goes to the one read first), once read `votesNeeded` times.
    public var expiry: MonthYear? {
        guard let most = dates.map(\.count).max(), most >= votesNeeded else { return nil }
        return dates.first { $0.count == most }?.date
    }

    /// The lote read most often; a tie goes to the longer one (a digit at the edge is the usual
    /// miss), then the alphabetically first so the answer doesn't flicker.
    public var lot: String? {
        lots.max { a, b in (a.value, a.key.count, b.key) < (b.value, b.key.count, a.key) }?.key
    }

    /// The scan to fill the form with: the voted lote and caducidad.
    public var scan: LotScan { LotScan(lot: lot, expiry: expiry) }
}
