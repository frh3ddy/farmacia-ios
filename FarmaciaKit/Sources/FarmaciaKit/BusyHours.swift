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

    public struct Response: Decodable, Sendable {
        public let timezone: String
        public let cells: [Cell]
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

    /// The three busiest slots, "lun 9 h · sáb 19 h · mar 9 h", so the grid isn't color alone.
    public var topText: String {
        guard !isEmpty else { return "Sin datos de ventas" }
        return cells.sorted { $0.orders > $1.orders }.prefix(3)
            .map { "\(Self.labels[$0.dayOfWeek]) \($0.hour) h" }
            .joined(separator: " · ")
    }
}
