import Testing
@testable import FarmaciaKit

/// What the Horas pico card and report show while loading, refreshing or failing.
/// (Mutating calls sit outside `#expect`, which can't take them.)
struct BusyHoursLoadTests {
    private let grid = BusyHours.Response(timezone: "America/Chicago", cells: [.init(dayOfWeek: 1, hour: 9, orders: 5)])
    private let newer = BusyHours.Response(timezone: "America/Chicago", cells: [.init(dayOfWeek: 2, hour: 10, orders: 7)])

    private func loaded(_ locationId: String = "centro", days: Int = 90) -> BusyHoursLoad {
        var load = BusyHoursLoad()
        _ = load.begin(locationId: locationId, days: days)
        load.finish(grid)
        return load
    }

    @Test("given no store selected, should say so instead of loading or failing")
    func noStore() {
        var load = BusyHoursLoad()
        let fetches = load.begin(locationId: nil, days: 90)
        #expect(!fetches)
        #expect(load.state == .noStore)
    }

    @Test("given a pull-to-refresh of the same store and period, should keep the grid until the new one lands")
    func refreshKeepsGrid() {
        var load = loaded()
        let fetches = load.begin(locationId: "centro", days: 90)
        #expect(fetches)
        #expect(load.state == .loaded(grid))
        load.finish(newer)
        #expect(load.state == .loaded(newer))
    }

    @Test("given another store or period, should clear the grid while it loads (never show the wrong one)")
    func switchClears() {
        var store = loaded()
        _ = store.begin(locationId: "norte", days: 90)
        #expect(store.state == .loading)
        var period = loaded()
        _ = period.begin(locationId: "centro", days: 30)
        #expect(period.state == .loading)
    }

    @Test("given a refresh that fails, should keep the last grid; a first load that fails, should say it failed")
    func failures() {
        var refresh = loaded()
        _ = refresh.begin(locationId: "centro", days: 90)
        refresh.finish(nil)
        #expect(refresh.state == .loaded(grid))
        var first = BusyHoursLoad()
        _ = first.begin(locationId: "centro", days: 90)
        first.finish(nil)
        #expect(first.state == .failed)
    }
}
