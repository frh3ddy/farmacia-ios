import Foundation

// MARK: - Tab Reset
//
// After a store switch, every tab but the selected one is rebuilt so no screen
// keeps the previous store's data or the previous role's access. The selected
// tab is the one hosting the switch screen (Inicio's root or Más → Ajustes),
// already showing nothing store-bound, and rebuilding it would cut the switch
// screen's success animation short.

public enum TabReset {
    public static func tabsToReset<Tab: Equatable>(all: [Tab], selected: Tab) -> [Tab] {
        all.filter { $0 != selected }
    }
}
