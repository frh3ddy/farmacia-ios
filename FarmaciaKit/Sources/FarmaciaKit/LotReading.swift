import Foundation

// MARK: - Lot Reading
//
// One opening of the lab lot reader, pass by pass (a pass = one frame through one
// `LotFilter`): feeds `LotVote`, accepts on the first plausible date (the date comes
// first; the lote is whatever was read by then) and builds the metrics row.
// After the accept it keeps counting for `followUp` seconds (DEBUG): how many later
// passes read the same date or another one, the data for deciding if 2 reads should
// be needed. The form is filled at the accept; the follow-up never delays it.

public struct LotReading: Sendable {
    public enum Event: Equatable, Sendable {
        /// Fill the form with this and close the scanner.
        case accept(LotScan)
        /// The follow-up is over: stop the camera and log the row.
        case done
    }

    private var vote: LotVote
    private let openedAt: Date
    private let followUp: TimeInterval
    private var passes = 0
    private var lotFirstRead: [String: Date] = [:]
    private var accepted: (scan: LotScan, at: Date, filter: LotFilter)?
    private var sameDateReads = 0
    private var otherDateReads = 0
    private var finished = false

    public init(today: MonthYear, openedAt: Date, votesNeeded: Int = 1, followUp: TimeInterval = 1) {
        vote = LotVote(today: today, votesNeeded: votesNeeded)
        self.openedAt = openedAt
        self.followUp = followUp
    }

    @discardableResult
    public mutating func pass(_ scan: LotScan, filter: LotFilter, at now: Date) -> Event? {
        guard !finished else { return nil }
        if let accepted {
            if now.timeIntervalSince(accepted.at) >= followUp {
                finished = true
                return .done
            }
            if let date = scan.expiry {
                if date == accepted.scan.expiry { sameDateReads += 1 } else { otherDateReads += 1 }
            }
            return nil
        }
        passes += 1
        if let lot = scan.lot, lotFirstRead[lot] == nil { lotFirstRead[lot] = now }
        vote.add(scan)
        guard vote.expiry != nil else { return nil }
        let result = vote.scan
        accepted = (result, now, filter)
        return .accept(result)
    }

    /// The row for this opening: a read, or a give-up when no date was taken.
    public func metrics(device: String) -> LotScanMetrics {
        let lot = accepted?.scan.lot ?? vote.lot
        return LotScanMetrics(
            date: openedAt, device: device, reader: .lab, lot: lot, expiry: accepted?.scan.expiry,
            msToExpiry: accepted.map { ms($0.at) }, msToLot: lot.flatMap { lotFirstRead[$0] }.map(ms),
            passes: passes, filter: accepted?.filter, edited: nil,
            sameDateReads: accepted == nil ? nil : sameDateReads, otherDateReads: accepted == nil ? nil : otherDateReads)
    }

    private func ms(_ date: Date) -> Int { Int((date.timeIntervalSince(openedAt) * 1000).rounded()) }
}
