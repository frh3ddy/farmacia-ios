import SwiftUI

// MARK: - Main Tab View
// Architecture: Products tab is the unified hub for product catalog + inventory operations.
// The standalone Inventory tab has been merged into Products to eliminate context switching.
// Users search once, see product info, and perform receive/adjust actions in the same context.

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: Tab = .dashboard
    
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
                    Label("Dashboard", systemImage: "chart.bar.xaxis")
                }
                .tag(Tab.dashboard)
            
            // Products (unified: catalog + inventory operations)
            ProductsView()
                .tabItem {
                    Label("Products", systemImage: "shippingbox.fill")
                }
                .tag(Tab.products)
            
            // Expenses (if has permission)
            if authManager.canManageExpenses {
                ExpensesView()
                    .tabItem {
                        Label("Expenses", systemImage: "creditcard")
                    }
                    .tag(Tab.expenses)
            }
            
            // Reports (if has permission)
            if authManager.canViewReports {
                ReportsView()
                    .tabItem {
                        Label("Reports", systemImage: "doc.text.magnifyingglass")
                    }
                    .tag(Tab.reports)
            }
            
            // Employees (if has permission)
            if authManager.canManageEmployees {
                EmployeesView()
                    .tabItem {
                        Label("Employees", systemImage: "person.3")
                    }
                    .tag(Tab.employees)
            }
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .accentColor(.blue)
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
}
