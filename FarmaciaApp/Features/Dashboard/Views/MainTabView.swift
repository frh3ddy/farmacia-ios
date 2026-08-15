import SwiftUI

// MARK: - Main Tab View
// Architecture: Products tab is the unified hub for product catalog + inventory operations.
// The standalone Inventory tab has been merged into Products to eliminate context switching.
// Users search once, see product info, and perform receive/adjust actions in the same context.

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: Tab = .dashboard
    
    /// Bumped every time a tab is selected; observed by child views to trigger a re-fetch.
    @State private var refreshTrigger: UUID = UUID()
    
    /// At most 4 direct tabs, always — Expenses/Payroll/Reports/Employees/
    /// Settings live inside `.more` instead of being individual tags. Beyond
    /// 5 tabs, iOS folds the rest into its own automatic "More" screen (its
    /// own UINavigationController), which double-nests navigation bars for
    /// any pushed view that also owns a NavigationStack. Keeping a hand-built
    /// "Más" tab avoids that entirely, regardless of permission combination.
    enum Tab: Hashable {
        case dashboard
        case products
        case alerts
        case more
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            DashboardView()
                .tabItem {
                    Label("Inicio", systemImage: "chart.bar.xaxis")
                }
                .tag(Tab.dashboard)

            // Products (unified: catalog + inventory operations)
            ProductsView(refreshTrigger: refreshTrigger)
                .tabItem {
                    Label("Productos", systemImage: "shippingbox.fill")
                }
                .tag(Tab.products)

            // Alerts (stock warnings, expiring products, actionable signals)
            AlertsView()
                .tabItem {
                    Label("Alertas", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(Tab.alerts)

            // Gastos, Nómina, Reportes, Empleados, Ajustes
            MoreView()
                .tabItem {
                    Label("Más", systemImage: "ellipsis")
                }
                .tag(Tab.more)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { _, _ in
            // Bump trigger so the newly-selected tab re-fetches fresh data
            refreshTrigger = UUID()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
