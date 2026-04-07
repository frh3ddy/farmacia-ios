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
    
    enum Tab: Hashable {
        case dashboard
        case products
        case expenses
        case reports
        case employees
        case settings
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
            
            // Expenses (if has permission)
            if authManager.canManageExpenses {
                ExpensesView()
                    .tabItem {
                        Label("Gastos", systemImage: "creditcard")
                    }
                    .tag(Tab.expenses)
            }
            
            // Reports (if has permission)
            if authManager.canViewReports {
                ReportsView()
                    .tabItem {
                        Label("Reportes", systemImage: "doc.text.magnifyingglass")
                    }
                    .tag(Tab.reports)
            }
            
            // Employees (if has permission)
            if authManager.canManageEmployees {
                EmployeesView()
                    .tabItem {
                        Label("Empleados", systemImage: "person.3")
                    }
                    .tag(Tab.employees)
            }
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(Tab.settings)
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
