import SwiftUI
import FarmaciaKit

// MARK: - Main Tab View
// Architecture: Products tab is the unified hub for product catalog + inventory operations.
// The standalone Inventory tab has been merged into Products to eliminate context switching.
// Users search once, see product info, and perform receive/adjust actions in the same context.

struct MainTabView<SyncStatus: View>: View {
    /// The offline/sync status, shown as the tab bar accessory on iOS 26.1+
    /// (RootView keeps a top banner on older versions).
    let syncStatus: SyncStatus
    let showsSyncStatus: Bool

    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: Tab = .dashboard
    
    /// Bumped every time a tab is selected; observed by child views to trigger a re-fetch.
    @State private var refreshTrigger: UUID = UUID()

    /// Each tab's identity. A new token rebuilds that tab at its root with fresh
    /// view models, so nothing loaded for the previous store or role survives a switch.
    @State private var tabTokens: [Tab: UUID] = [:]
    
    /// At most 4 direct tabs, always — Expenses/Payroll/Reports/Employees/
    /// Settings live inside `.more` instead of being individual tags. Beyond
    /// 5 tabs, iOS folds the rest into its own automatic "More" screen (its
    /// own UINavigationController), which double-nests navigation bars for
    /// any pushed view that also owns a NavigationStack. Keeping a hand-built
    /// "Más" tab avoids that entirely, regardless of permission combination.
    enum Tab: Hashable, CaseIterable {
        case dashboard
        case products
        case alerts
        case more
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            DashboardView()
                .id(tabTokens[.dashboard])
                .tabItem {
                    Label("Inicio", systemImage: "chart.bar.xaxis")
                }
                .tag(Tab.dashboard)

            // Products (unified: catalog + inventory operations)
            ProductsView(refreshTrigger: refreshTrigger)
                .id(tabTokens[.products])
                .tabItem {
                    Label("Productos", systemImage: "shippingbox.fill")
                }
                .tag(Tab.products)

            // Alerts (stock warnings, expiring products, actionable signals)
            AlertsView()
                .id(tabTokens[.alerts])
                .tabItem {
                    Label("Alertas", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(Tab.alerts)

            // Gastos, Nómina, Reportes, Empleados, Ajustes
            MoreView()
                .id(tabTokens[.more])
                .tabItem {
                    Label("Más", systemImage: "ellipsis")
                }
                .tag(Tab.more)
        }
        .accentColor(.blue)
        .syncStatusAccessory(isEnabled: showsSyncStatus) { syncStatus }
        .onChange(of: selectedTab) { _, _ in
            // Bump trigger so the newly-selected tab re-fetches fresh data
            refreshTrigger = UUID()
        }
        .onChange(of: authManager.currentLocation?.id) {
            // The selected tab hosts the switch screen; the rest may hold the old store's screens
            for tab in TabReset.tabsToReset(all: Tab.allCases, selected: selectedTab) {
                tabTokens[tab] = UUID()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView(syncStatus: EmptyView(), showsSyncStatus: false)
        .environmentObject(AuthManager.shared)
}

private extension View {
    /// The tab bar accessory (iOS 26.1+: the version that can be turned off
    /// when there's nothing to say). Earlier versions show nothing here.
    @ViewBuilder
    func syncStatusAccessory<Content: View>(isEnabled: Bool, @ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isEnabled, content: content)
        } else {
            self
        }
    }
}
