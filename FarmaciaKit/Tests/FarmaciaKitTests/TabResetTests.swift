import Testing
@testable import FarmaciaKit

struct TabResetTests {
    enum Tab: CaseIterable { case dashboard, products, alerts, more }

    @Test("given a store change while Más is selected, should rebuild Inicio, Productos and Alertas but not Más")
    func moreSelected() {
        #expect(TabReset.tabsToReset(all: Tab.allCases, selected: .more) == [.dashboard, .products, .alerts])
    }

    @Test("given Inicio selected, should rebuild the other three")
    func dashboardSelected() {
        #expect(TabReset.tabsToReset(all: Tab.allCases, selected: .dashboard) == [.products, .alerts, .more])
    }
}
