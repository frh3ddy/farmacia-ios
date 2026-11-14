import Foundation

// MARK: - Busy Hours
//
// GET /inventory/reports/busy-hours: distinct orders per weekday × hour, in the
// API's `timezone`. Only non-empty cells come back; the rest are 0. The grid
// spans the hours that had any order and runs Monday-first.
public struct BusyHours: Equatable, Sendable {
    public struct Cell: Decodable, Equatable, Sendable {
        public let dayOfWeek: Int // 0 = Sunday
        public let hour: Int
        public let orders: Int
        public init(dayOfWeek: Int, hour: Int, orders: Int) {
            self.dayOfWeek = dayOfWeek
            self.hour = hour
            self.orders = orders
        }
    }

    public struct Response: Decodable, Equatable, Sendable {
        public let timezone: String
        public let cells: [Cell]
        public init(timezone: String, cells: [Cell]) {
            self.timezone = timezone
            self.cells = cells
        }
    }

    public struct Day: Equatable, Sendable {
        public let dayOfWeek: Int
        public let label: String
    }

    private static let labels = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    public let days = [1, 2, 3, 4, 5, 6, 0].map { Day(dayOfWeek: $0, label: labels[$0]) }
    public let hours: [Int]
    private let cells: [Cell]
    private let busiest: Int

    public init(cells: [Cell]) {
        self.cells = cells.filter { $0.orders > 0 }
        busiest = self.cells.map(\.orders).max() ?? 0
        let all = self.cells.map(\.hour)
        hours = all.min().map { Array($0...all.max()!) } ?? []
    }

    public var isEmpty: Bool { cells.isEmpty }

    /// Orders in a slot as a share of the busiest slot, 0…1.
    public func share(day: Int, hour: Int) -> Double {
        busiest > 0 ? Double(orders(day: day, hour: hour)) / Double(busiest) : 0
    }

    public func orders(day: Int, hour: Int) -> Int {
        cells.first { $0.dayOfWeek == day && $0.hour == hour }?.orders ?? 0
    }

    /// The three busiest slots, "lun 9 h", "sáb 19 h", "mar 9 h". Equal counts: Monday-first
    /// (Sunday last), then the earlier hour, so the order never reshuffles.
    public var topSlots: [String] {
        let mondayFirst = { (day: Int) in (day + 6) % 7 }
        return cells.sorted {
            ($1.orders, mondayFirst($0.dayOfWeek), $0.hour) < ($0.orders, mondayFirst($1.dayOfWeek), $1.hour)
        }.prefix(3).map { "\(Self.labels[$0.dayOfWeek]) \($0.hour) h" }
    }

    /// "lun 9 h · sáb 19 h · mar 9 h", so the grid isn't color alone.
    public var topText: String {
        isEmpty ? "Sin datos de ventas" : topSlots.joined(separator: " · ")
    }

    /// "Pedidos por hora · hora de Ciudad de México": the grid's hours are the API's time zone,
    /// named by its city (the id's last part, Spanish where it differs).
    public static func caption(timezone: String) -> String {
        let city = timezone.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? timezone
        let spanish = ["Mexico City": "Ciudad de México"]
        return "Pedidos por hora · hora de \(spanish[city] ?? city)"
    }
}

// MARK: - Busy Hours Load
//
// What the card and report show: a refresh of the same store and period keeps the grid
// (and keeps it if the refresh fails); another store or period clears it, so the wrong
// grid is never on screen; no store selected is its own state, not a failure.
public struct BusyHoursLoad: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case loading, noStore, failed
        case loaded(BusyHours.Response)
    }

    /// One load's store and period. `finish` applies an answer only for the current store and
    /// period, so a slow answer for an earlier one never lands; answers for the same store and
    /// period carry the same data, so any of them may land (a cancelled refresh can't strand
    /// the first load's answer).
    public struct Ticket: Equatable, Sendable {
        let locationId: String
        let days: Int
    }

    public private(set) var state: State = .loading
    private var current: Ticket?
    /// Loads still running for `current`: a failure shows only when none is left to answer.
    private var inFlight = 0

    public init() {}

    /// Starts a load and returns its ticket; nil when there's nothing to fetch (no store selected).
    public mutating func begin(locationId: String?, days: Int) -> Ticket? {
        guard let locationId else {
            current = nil
            inFlight = 0
            state = .noStore
            return nil
        }
        let next = Ticket(locationId: locationId, days: days)
        inFlight = next == current ? inFlight + 1 : 1
        // A refresh keeps the grid until the new one lands; another store or period clears it.
        if case .loaded = state, next == current { return next }
        current = next
        state = .loading
        return next
    }

    /// The load for `ticket` was cancelled (its view went away) and will never answer.
    public mutating func cancel(_ ticket: Ticket) {
        guard ticket == current, inFlight > 0 else { return }
        inFlight -= 1 // not a failure: the next appearance loads again
    }

    /// The answer for `ticket`; nil when it failed.
    public mutating func finish(_ response: BusyHours.Response?, for ticket: Ticket) {
        guard ticket == current else { return } // another store or period (or no store) owns the screen
        inFlight = max(0, inFlight - 1)
        if let response {
            state = .loaded(response)
        } else if case .loaded = state {
            return // a failed refresh keeps the last grid
        } else if inFlight == 0 {
            state = .failed // only once no other load for this store and period can still answer
        }
    }
}
