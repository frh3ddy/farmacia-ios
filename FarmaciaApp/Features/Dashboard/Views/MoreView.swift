import SwiftUI

// MARK: - More View
// A hand-built "Más" tab standing in for iOS's automatic tab-bar overflow
// screen. TabView only shows 5 tabs directly; beyond that it folds the rest
// into a native "More" list, which is its own UINavigationController. Any
// pushed screen that also declares its own NavigationStack then ends up with
// two stacked nav bars (the system's "More" back button in one row, our
// title/toolbar in another). Owning this list ourselves keeps everything in
// a single NavigationStack, so there's exactly one nav bar.

struct MoreView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            List {
                if authManager.canManageExpenses {
                    NavigationLink {
                        ExpensesView()
                    } label: {
                        Label("Gastos", systemImage: "creditcard")
                    }

                    NavigationLink {
                        PayrollView()
                    } label: {
                        Label("Nómina", systemImage: "person.badge.clock")
                    }
                }

                if authManager.canViewReports {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Reportes", systemImage: "doc.text.magnifyingglass")
                    }
                }

                if authManager.canManageEmployees {
                    NavigationLink {
                        EmployeesView()
                    } label: {
                        Label("Empleados", systemImage: "person.3")
                    }
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Ajustes", systemImage: "gearshape")
                }
            }
            .navigationTitle("Más")
        }
    }
}

// MARK: - Preview

#Preview {
    MoreView()
        .environmentObject(AuthManager.shared)
}
