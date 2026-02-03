import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: Hashable {
        case dashboard
        case inventory
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
            
            // Inventory
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox")
                }
                .tag(Tab.inventory)
            
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
