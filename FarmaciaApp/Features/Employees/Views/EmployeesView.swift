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
                } else if let error = viewModel.errorMessage, viewModel.employees.isEmpty {
                    errorView(message: error)
                } else if viewModel.employees.isEmpty {
                    emptyView
                } else {
                    employeeList
                }
            }
            .navigationTitle("Empleados")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.currentLocation?.role == .owner {
                        Button {
                            viewModel.showAddEmployee = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddEmployee) {
                AddEmployeeView(viewModel: viewModel)
            }
            .sheet(item: $viewModel.selectedEmployee) { employee in
                EmployeeDetailView(employee: employee, viewModel: viewModel)
            }
            .refreshable {
                await viewModel.loadEmployees()
            }
            .task {
                await viewModel.loadEmployees()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Cargando empleados...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error al Cargar")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    await viewModel.loadEmployees()
                }
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Hay Empleados Aún")
                .font(.headline)
            
            Text("Agrega empleados para permitirles iniciar sesión y acceder al sistema.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if authManager.currentLocation?.role == .owner {
                Button {
                    viewModel.showAddEmployee = true
                } label: {
                    Label("Agregar Empleado", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Employee List
    
    private var employeeList: some View {
        List {
            ForEach(viewModel.employees) { employee in
                Button {
                    viewModel.selectedEmployee = employee
                } label: {
                    EmployeeRow(employee: employee)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
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
                Text(employee.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    // Role badge
                    Text(employee.primaryRole.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(roleColor.opacity(0.2))
                        .foregroundColor(roleColor)
                        .cornerRadius(4)
                    
                    // PIN status
                    if !employee.hasPIN {
                        HStack(spacing: 2) {
                            Image(systemName: "key.slash")
                                .font(.caption2)
                            Text("Sin PIN")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                    
                    // Location count
                    if let assignments = employee.assignments, assignments.count > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: "building.2")
                                .font(.caption2)
                            Text("\(assignments.count)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(employee.isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var roleColor: Color {
        switch employee.primaryRole {
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
    @ObservedObject var viewModel: EmployeesViewModel
    @EnvironmentObject var authManager: AuthManager
    
    @State private var name = ""
    @State private var email = ""
    @State private var pin = ""
    @State private var selectedRole: EmployeeRole = .cashier
    @State private var isSubmitting = false
    @State private var showPINField = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Información Básica") {
                    TextField("Nombre Completo", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                }
                
                Section("Contacto (Opcional)") {
                    TextField("Correo Electrónico", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                }
                
                Section("Rol") {
                    Picker("Rol", selection: $selectedRole) {
                        // Don't allow creating other Owners
                        ForEach([EmployeeRole.manager, .cashier, .accountant], id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    
                    Text(roleDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Toggle("Establecer PIN Ahora", isOn: $showPINField)
                    
                    if showPINField {
                        SecureField("PIN de 4-6 Dígitos", text: $pin)
                            .keyboardType(.numberPad)
                        
                        if !pin.isEmpty && !isValidPIN {
                            Text("El PIN debe tener 4-6 dígitos")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("PIN")
                } footer: {
                    Text("Si no lo estableces ahora, puedes hacerlo después desde el detalle del empleado.")
                }
            }
            .navigationTitle("Agregar Empleado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        Task {
                            await createEmployee()
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Creando...")
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (pin.isEmpty || isValidPIN)
    }
    
    private var isValidPIN: Bool {
        let digits = pin.filter { $0.isNumber }
        return digits.count >= 4 && digits.count <= 6
    }
    
    private var roleDescription: String {
        switch selectedRole {
        case .owner:
            return "Acceso completo a todas las funciones"
        case .manager:
            return "Puede gestionar inventario, ver reportes y manejar gastos"
        case .cashier:
            return "Solo puede ver inventario"
        case .accountant:
            return "Puede gestionar gastos y ver todos los reportes"
        }
    }
    
    private func createEmployee() async {
        guard let locationId = authManager.currentLocation?.id else {
            viewModel.errorMessage = "No hay ubicación seleccionada"
            viewModel.showError = true
            return
        }
        isSubmitting = true
        let success = await viewModel.createEmployee(
            name: name,
            email: email.isEmpty ? nil : email,
            pin: showPINField ? (pin.isEmpty ? nil : pin) : nil,
            locationId: locationId,
            role: selectedRole
        )
        isSubmitting = false
        if success { dismiss() }
    }
}

// MARK: - Employee Detail View

struct EmployeeDetailView: View {
    let employee: Employee
    @ObservedObject var viewModel: EmployeesViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showSetPIN = false
    @State private var showDeactivate = false
    @State private var showResetLockout = false
    @State private var newPIN = ""
    @State private var isPerformingAction = false
    @State private var detailEmployee: EmployeeDetail?
    @State private var isLoadingDetail = false
    
    private var isOwner: Bool {
        authManager.currentLocation?.role == .owner
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Basic Info Section
                Section("Información") {
                    LabeledContent("Nombre", value: employee.displayName)
                    
                    if let email = employee.email {
                        LabeledContent("Correo Electrónico", value: email)
                    }
                    
                    LabeledContent("Rol", value: employee.primaryRole.displayName)
                }
                
                // Status Section
                Section("Estado") {
                    HStack {
                        Text("Activo")
                        Spacer()
                        Image(systemName: employee.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(employee.isActive ? .green : .red)
                    }
                    
                    HStack {
                        Text("PIN Establecido")
                        Spacer()
                        Image(systemName: employee.hasPIN ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(employee.hasPIN ? .green : .orange)
                    }
                    
                    if let detail = detailEmployee {
                        if detail.isLocked, let lockedUntil = detail.lockedUntil {
                            HStack {
                                Text("Bloqueado Hasta")
                                Spacer()
                                Text(lockedUntil, style: .time)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        if detail.failedPinAttempts > 0 {
                            LabeledContent("Intentos Fallidos de PIN", value: "\(detail.failedPinAttempts)")
                        }
                    }
                    
                    if let lastLogin = employee.lastLoginAt {
                        LabeledContent("Último Acceso") {
                            Text(lastLogin, style: .relative)
                        }
                    }
                }
                
                // Locations Section
                if let assignments = employee.assignments, !assignments.isEmpty {
                    Section("Ubicaciones") {
                        ForEach(assignments) { assignment in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(assignment.locationName)
                                    Text(assignment.role.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                
                // Actions Section - Only for Owners
                if isOwner {
                    Section("Acciones") {
                        // Set/Reset PIN
                        Button {
                            showSetPIN = true
                        } label: {
                            Label(employee.hasPIN ? "Restablecer PIN" : "Establecer PIN", systemImage: "key")
                        }
                        
                        // Reset lockout (if locked)
                        if let detail = detailEmployee, detail.isLocked {
                            Button {
                                showResetLockout = true
                            } label: {
                                Label("Desbloquear Cuenta", systemImage: "lock.open")
                            }
                            .foregroundColor(.orange)
                        }
                        
                        // Deactivate (if active and not self)
                        if employee.isActive && employee.id != authManager.currentEmployee?.id {
                            Button(role: .destructive) {
                                showDeactivate = true
                            } label: {
                                Label("Desactivar Empleado", systemImage: "person.slash")
                            }
                        }
                    }
                }
            }
            .navigationTitle(employee.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadEmployeeDetail()
            }
            .overlay {
                if isPerformingAction {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(.ultraThickMaterial)
                        .cornerRadius(10)
                }
            }
            // Set PIN Alert
            .alert("Establecer PIN", isPresented: $showSetPIN) {
                SecureField("PIN de 4-6 Dígitos", text: $newPIN)
                    .keyboardType(.numberPad)
                Button("Cancelar", role: .cancel) {
                    newPIN = ""
                }
                Button("Establecer") {
                    Task {
                        await setPIN()
                    }
                }
                .disabled(!isValidNewPIN)
            } message: {
                Text("Ingresa un nuevo PIN de 4-6 dígitos para este empleado.")
            }
            // Deactivate Confirmation
            .alert("Desactivar Empleado", isPresented: $showDeactivate) {
                Button("Cancelar", role: .cancel) {}
                Button("Desactivar", role: .destructive) {
                    Task {
                        await deactivateEmployee()
                    }
                }
            } message: {
                Text("Este empleado ya no podrá iniciar sesión. Esta acción se puede revertir reactivándolo.")
            }
            // Reset Lockout Confirmation
            .alert("Desbloquear Cuenta", isPresented: $showResetLockout) {
                Button("Cancelar", role: .cancel) {}
                Button("Desbloquear") {
                    Task {
                        await resetLockout()
                    }
                }
            } message: {
                Text("Esto restablecerá los intentos fallidos de PIN y permitirá al empleado iniciar sesión nuevamente.")
            }
        }
    }
    
    private var isValidNewPIN: Bool {
        let digits = newPIN.filter { $0.isNumber }
        return digits.count >= 4 && digits.count <= 6
    }
    
    private func loadEmployeeDetail() async {
        isLoadingDetail = true
        detailEmployee = await viewModel.getEmployeeDetail(id: employee.id)
        isLoadingDetail = false
    }
    
    private func setPIN() async {
        isPerformingAction = true
        let success = await viewModel.setPIN(employeeId: employee.id, pin: newPIN)
        isPerformingAction = false
        newPIN = ""
        
        if success {
            await viewModel.loadEmployees()
            dismiss()
        }
    }
    
    private func deactivateEmployee() async {
        isPerformingAction = true
        let success = await viewModel.deactivateEmployee(id: employee.id)
        isPerformingAction = false
        
        if success {
            await viewModel.loadEmployees()
            dismiss()
        }
    }
    
    private func resetLockout() async {
        isPerformingAction = true
        let success = await viewModel.resetPINLockout(employeeId: employee.id)
        isPerformingAction = false
        
        if success {
            await loadEmployeeDetail()
        }
    }
}

// MARK: - Employees View Model

@MainActor
class EmployeesViewModel: ObservableObject {
    @Published var employees: [Employee] = []
    @Published var isLoading = false
    @Published var showAddEmployee = false
    @Published var selectedEmployee: Employee?
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let apiClient = APIClient.shared
    
    // MARK: - Load Employees
    
    func loadEmployees() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: EmployeeListResponse = try await apiClient.request(endpoint: .listEmployees)
            employees = response.data
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            if employees.isEmpty {
                // Only show error alert if we have no data
            } else {
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            if employees.isEmpty {
            } else {
                showError = true
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Get Employee Detail
    
    func getEmployeeDetail(id: String) async -> EmployeeDetail? {
        do {
            let response: EmployeeDetailResponse = try await apiClient.request(
                endpoint: .getEmployee(id: id)
            )
            return response.data
        } catch {
            print("Failed to load employee detail: \(error)")
            return nil
        }
    }
    
    // MARK: - Create Employee
    
    func createEmployee(name: String, email: String?, pin: String?, locationId: String, role: EmployeeRole) async -> Bool {
        do {
            let request = CreateEmployeeRequest(
                name: name,
                email: email,
                pin: pin,
                locationId: locationId,
                role: role
            )
            
            let _: CreateEmployeeResponse = try await apiClient.request(
                endpoint: .createEmployee,
                body: request
            )
            
            // Reload the list
            await loadEmployees()
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    // MARK: - Set PIN
    
    func setPIN(employeeId: String, pin: String) async -> Bool {
        do {
            let request = SetPINRequest(pin: pin)
            let _: EmployeeActionResponse = try await apiClient.request(
                endpoint: .resetPIN(employeeId: employeeId),
                body: request
            )
            return true
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            showError = true
            return false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    // MARK: - Deactivate Employee
    
    func deactivateEmployee(id: String) async -> Bool {
        do {
            let _: EmployeeActionResponse = try await apiClient.request(
                endpoint: .deleteEmployee(id: id)
            )
            return true
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            showError = true
            return false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
    
    // MARK: - Reset PIN Lockout
    
    func resetPINLockout(employeeId: String) async -> Bool {
        do {
            let _: EmployeeActionResponse = try await apiClient.request(
                endpoint: .resetPINLockout(employeeId: employeeId)
            )
            return true
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            showError = true
            return false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return false
        }
    }
}

// MARK: - Preview

#Preview {
    EmployeesView()
        .environmentObject(AuthManager.shared)
}

