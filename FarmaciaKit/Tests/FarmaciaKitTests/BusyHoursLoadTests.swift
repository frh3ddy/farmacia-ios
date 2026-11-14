import Testing
@testable import FarmaciaKit

/// What the Horas pico card and report show while loading, refreshing or failing.
/// (Mutating calls sit outside `#expect`, which can't take them.)
struct BusyHoursLoadTests {
    private let grid = BusyHours.Response(timezone: "America/Chicago", cells: [.init(dayOfWeek: 1, hour: 9, orders: 5)])
    private let newer = BusyHours.Response(timezone: "America/Chicago", cells: [.init(dayOfWeek: 2, hour: 10, orders: 7)])

    private func loaded(_ locationId: String = "centro", days: Int = 90) -> BusyHoursLoad {
        var load = BusyHoursLoad()
        let ticket = load.begin(locationId: locationId, days: days)!
        load.finish(grid, for: ticket)
        return load
    }

    @Test("given no store selected, should say so instead of loading or failing")
    func noStore() {
        var load = BusyHoursLoad()
        let ticket = load.begin(locationId: nil, days: 90)
        #expect(ticket == nil)
        #expect(load.state == .noStore)
    }

    @Test("given a pull-to-refresh of the same store and period, should keep the grid until the new one lands")
    func refreshKeepsGrid() {
        var load = loaded()
        let ticket = load.begin(locationId: "centro", days: 90)!
        #expect(load.state == .loaded(grid))
        load.finish(newer, for: ticket)
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
        let refreshTicket = refresh.begin(locationId: "centro", days: 90)!
        refresh.finish(nil, for: refreshTicket)
        #expect(refresh.state == .loaded(grid))
        var first = BusyHoursLoad()
        let firstTicket = first.begin(locationId: "centro", days: 90)!
        first.finish(nil, for: firstTicket)
        #expect(first.state == .failed)
    }

    @Test("given a refresh at store A still in flight when store B is picked, A's answer should never show under B")
    func staleAnswerDropped() {
        var load = loaded("A")
        let refreshA = load.begin(locationId: "A", days: 90)!
        let storeB = load.begin(locationId: "B", days: 90)!
        load.finish(grid, for: refreshA)
        #expect(load.state == .loading)
        load.finish(newer, for: storeB)
        #expect(load.state == .loaded(newer))
        load.finish(grid, for: refreshA) // landing after B, too
        #expect(load.state == .loaded(newer))
    }

    @Test("given the first load in flight and a refresh started then cancelled, the first load's answer should still show the grid")
    func cancelledRefreshDoesNotStrand() {
        var load = BusyHoursLoad()
        let first = load.begin(locationId: "A", days: 90)!
        _ = load.begin(locationId: "A", days: 90) // pull-to-refresh, then cancelled: never finishes
        load.finish(grid, for: first)
        #expect(load.state == .loaded(grid))
    }

    @Test("given a load from before no store was selected, its answer should not land")
    func answerBeforeNoStoreDropped() {
        var load = BusyHoursLoad()
        let a = load.begin(locationId: "A", days: 90)!
        _ = load.begin(locationId: nil, days: 90)
        load.finish(grid, for: a)
        #expect(load.state == .noStore)
    }

    @Test("given the first load failing while a refresh is still running, should stay loading, then show the refresh's grid")
    func failureWaitsForRefresh() {
        var load = BusyHoursLoad()
        let first = load.begin(locationId: "A", days: 90)!
        let refresh = load.begin(locationId: "A", days: 90)!
        load.finish(nil, for: first)
        #expect(load.state == .loading)
        load.finish(grid, for: refresh)
        #expect(load.state == .loaded(grid))
    }

    @Test("given both loads failing, should show the failure only after the last one")
    func failsAfterLast() {
        var load = BusyHoursLoad()
        let first = load.begin(locationId: "A", days: 90)!
        let refresh = load.begin(locationId: "A", days: 90)!
        load.finish(nil, for: first)
        load.finish(nil, for: refresh)
        #expect(load.state == .failed)
    }

    @Test("given the refresh cancelled and then the first load failing, should show the failure, not stay loading")
    func cancelledThenFailed() {
        var load = BusyHoursLoad()
        let first = load.begin(locationId: "A", days: 90)!
        let refresh = load.begin(locationId: "A", days: 90)!
        load.cancel(refresh)
        load.finish(nil, for: first)
        #expect(load.state == .failed)
    }
}
