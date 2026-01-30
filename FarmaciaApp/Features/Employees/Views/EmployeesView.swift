import SwiftUI

// MARK: - Employees View

struct EmployeesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = EmployeesViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.employees.isEmpty {
                    loadingView
                } else if viewModel.employees.isEmpty {
                    emptyView
                } else {
                    employeeList
                }
            }
            .navigationTitle("Employees")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showAddEmployee = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddEmployee) {
                AddEmployeeView()
            }
            .refreshable {
                await viewModel.loadEmployees()
            }
            .task {
                await viewModel.loadEmployees()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading employees...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Employees Yet")
                .font(.headline)
            
            Text("Add employees to allow them to log in and access the system.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                viewModel.showAddEmployee = true
            } label: {
                Label("Add Employee", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Employee List
    
    private var employeeList: some View {
        List {
            ForEach(viewModel.employees) { employee in
                NavigationLink {
                    EmployeeDetailView(employee: employee)
                } label: {
                    EmployeeRow(employee: employee)
                }
            }
        }
    }
}

// MARK: - Employee Row

struct EmployeeRow: View {
    let employee: Employee
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Text(employee.initials)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(roleColor)
                .clipShape(Circle())
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(employee.fullName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(employee.role.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.2))
                        .foregroundColor(roleColor)
                        .cornerRadius(4)
                    
                    if !employee.pinSet {
                        Text("PIN not set")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if employee.isLocked {
                        Text("Locked")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(employee.isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
    
    private var roleColor: Color {
        switch employee.role {
        case .owner: return .purple
        case .manager: return .blue
        case .cashier: return .green
        case .accountant: return .orange
        }
    }
}

// MARK: - Add Employee View

struct AddEmployeeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedRole: EmployeeRole = .cashier
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }
                
                Section("Contact (Optional)") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("Role") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach([EmployeeRole.manager, .cashier, .accountant], id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    
                    Text(roleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save employee
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)
                }
            }
        }
    }
    
    private var roleDescription: String {
        switch selectedRole {
        case .owner:
            return "Full access to all features"
        case .manager:
            return "Can manage inventory, view reports, and handle expenses"
        case .cashier:
            return "Can view inventory only"
        case .accountant:
            return "Can manage expenses and view all reports"
        }
    }
}

// MARK: - Employee Detail View

struct EmployeeDetailView: View {
    let employee: Employee
    @State private var showResetPIN = false
    @State private var showDeactivate = false
    
    var body: some View {
        List {
            // Basic Info Section
            Section("Information") {
                LabeledContent("Name", value: employee.fullName)
                LabeledContent("Role", value: employee.role.displayName)
                
                if let email = employee.email {
                    LabeledContent("Email", value: email)
                }
                
                if let phone = employee.phone {
                    LabeledContent("Phone", value: phone)
                }
            }
            
            // Status Section
            Section("Status") {
                LabeledContent("Active", value: employee.isActive ? "Yes" : "No")
                LabeledContent("PIN Set", value: employee.pinSet ? "Yes" : "No")
                
                if employee.isLocked, let lockedUntil = employee.lockedUntil {
                    LabeledContent("Locked Until") {
                        Text(lockedUntil, style: .time)
                            .foregroundColor(.red)
                    }
                }
                
                if let lastLogin = employee.lastLoginAt {
                    LabeledContent("Last Login") {
                        Text(lastLogin, style: .relative)
                    }
                }
            }
            
            // Locations Section
            if let assignments = employee.locationAssignments, !assignments.isEmpty {
                Section("Locations") {
                    ForEach(assignments) { assignment in
                        HStack {
                            Text(assignment.location?.name ?? "Unknown")
                            
                            Spacer()
                            
                            if assignment.isDefault {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            // Actions Section
            Section {
                Button {
                    showResetPIN = true
                } label: {
                    Label("Reset PIN", systemImage: "key")
                }
                
                Button(role: .destructive) {
                    showDeactivate = true
                } label: {
                    Label("Deactivate Employee", systemImage: "person.slash")
                }
            }
        }
        .navigationTitle(employee.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset PIN", isPresented: $showResetPIN) {
            Button("Cancel", role: .cancel) {}
            Button("Reset") {
                // TODO: Reset PIN
            }
        } message: {
            Text("This will allow the employee to set a new PIN on their next login.")
        }
        .alert("Deactivate Employee", isPresented: $showDeactivate) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                // TODO: Deactivate employee
            }
        } message: {
            Text("This employee will no longer be able to log in.")
        }
    }
}

// MARK: - Employees View Model

@MainActor
class EmployeesViewModel: ObservableObject {
    @Published var employees: [Employee] = []
    @Published var isLoading = false
    @Published var showAddEmployee = false
    
    private let apiClient = APIClient.shared
    
    func loadEmployees() async {
        isLoading = true
        
        // TODO: Load employees from API
        // For now, just set loading to false
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    EmployeesView()
        .environmentObject(AuthManager.shared)
}
