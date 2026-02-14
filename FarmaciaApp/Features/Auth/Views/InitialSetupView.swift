import SwiftUI

// MARK: - Initial Setup View

struct InitialSetupView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InitialSetupViewModel()
    var onSetupComplete: () -> Void
    var onSwitchToLogin: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Form
                    formSection
                    
                    // Submit Button
                    submitButton
                    
                    // Switch to Login
                    switchToLoginButton
                }
                .padding(24)
            }
            .navigationTitle("Bienvenido")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadAvailableLocations()
            }
            .alert("Error de Configuración", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("¡Configuración Completa!", isPresented: $viewModel.showSuccess) {
                Button("Continuar") {
                    onSetupComplete()
                }
            } message: {
                Text("Tu cuenta ha sido creada. Ya puedes iniciar sesión.")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Configura Tu Farmacia")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Crea tu cuenta de dueño y ubicación de farmacia para comenzar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 24) {
            // Owner Info Section
            VStack(alignment: .leading, spacing: 16) {
                Label("Cuenta de Dueño", systemImage: "person.fill")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    TextField("Tu Nombre", text: $viewModel.ownerName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    TextField("Correo Electrónico", text: $viewModel.ownerEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Contraseña (mín 6 caracteres)", text: $viewModel.ownerPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirmar Contraseña", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("PIN (4-6 dígitos)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("PIN", text: $viewModel.ownerPin)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .onChange(of: viewModel.ownerPin) { _, newValue in
                                    viewModel.ownerPin = String(newValue.filter { $0.isNumber }.prefix(6))
                                }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Confirmar PIN")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("Confirmar", text: $viewModel.confirmPin)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .onChange(of: viewModel.confirmPin) { _, newValue in
                                    viewModel.confirmPin = String(newValue.filter { $0.isNumber }.prefix(6))
                                }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Location Section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Ubicación de Farmacia", systemImage: "building.2.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Sync from Square button
                    Button {
                        Task {
                            await viewModel.syncFromSquare()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if viewModel.isSyncingSquare {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            }
                            Text("Sincronizar Square")
                                .font(.caption)
                        }
                    }
                    .disabled(viewModel.isSyncingSquare)
                    .foregroundColor(.blue)
                }
                
                // Show location choice if locations exist
                if !viewModel.availableLocations.isEmpty {
                    Picker("Opción de Ubicación", selection: $viewModel.useExistingLocation) {
                        Text("Usar ubicación existente").tag(true)
                        Text("Crear nueva ubicación").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if viewModel.useExistingLocation {
                        // Location picker
                        Picker("Seleccionar Ubicación", selection: $viewModel.selectedLocationId) {
                            ForEach(viewModel.availableLocations, id: \.id) { location in
                                HStack {
                                    Text(location.name)
                                    if location.squareId != nil {
                                        Text("(Square)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(location.id)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Text("\(viewModel.availableLocations.count) ubicación(es) disponibles de la sincronización con Square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        TextField("Nombre de Farmacia", text: $viewModel.locationName)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                } else {
                    Text("No se encontraron ubicaciones. Toca 'Sincronizar Square' para importar de Square, o ingresa un nombre abajo.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Nombre de Farmacia", text: $viewModel.locationName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button {
            Task {
                await viewModel.submitSetup()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Completar Configuración")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isFormValid ? Color.green : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .fontWeight(.semibold)
        }
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
    }
    
    // MARK: - Switch to Login Button
    
    private var switchToLoginButton: some View {
        Button {
            onSwitchToLogin()
        } label: {
            Text("¿Ya tienes cuenta? Iniciar sesión")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Initial Setup View Model

@MainActor
class InitialSetupViewModel: ObservableObject {
    @Published var ownerName = ""
    @Published var ownerEmail = ""
    @Published var ownerPassword = ""
    @Published var confirmPassword = ""
    @Published var ownerPin = ""
    @Published var confirmPin = ""
    @Published var locationName = ""
    
    // Location selection
    @Published var availableLocations: [SetupAvailableLocation] = []
    @Published var useExistingLocation = false
    @Published var selectedLocationId = ""
    @Published var isLoadingLocations = true
    @Published var isSyncingSquare = false
    
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    
    var isFormValid: Bool {
        let ownerValid = !ownerName.isEmpty &&
            ownerName.count >= 2 &&
            !ownerEmail.isEmpty &&
            ownerEmail.contains("@") &&
            ownerPassword.count >= 6 &&
            ownerPassword == confirmPassword &&
            ownerPin.count >= 4 &&
            ownerPin == confirmPin
        
        // Location validation
        let locationValid: Bool
        if useExistingLocation {
            locationValid = !selectedLocationId.isEmpty
        } else {
            locationValid = !locationName.isEmpty && locationName.count >= 2
        }
        
        return ownerValid && locationValid
    }
    
    func loadAvailableLocations() async {
        isLoadingLocations = true
        
        do {
            let response: SetupStatusResponse = try await APIClient.shared.request(
                endpoint: .setupStatus
            )
            
            if let locations = response.data.locations, !locations.isEmpty {
                availableLocations = locations
                useExistingLocation = true
                selectedLocationId = locations.first?.id ?? ""
            }
        } catch {
            print("[Setup] Failed to load locations: \(error)")
            // Not critical - just means user will create a new location
        }
        
        isLoadingLocations = false
    }
    
    func syncFromSquare() async {
        isSyncingSquare = true
        
        do {
            let response: SyncLocationsResponse = try await APIClient.shared.request(
                endpoint: .setupSyncLocations
            )
            
            if let locations = response.data.locations, !locations.isEmpty {
                availableLocations = locations
                useExistingLocation = true
                selectedLocationId = locations.first?.id ?? ""
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Error al sincronizar con Square"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSyncingSquare = false
    }
    
    func submitSetup() async {
        guard isFormValid else { return }
        
        isLoading = true
        
        do {
            let request = InitialSetupRequest(
                ownerName: ownerName,
                ownerEmail: ownerEmail,
                ownerPassword: ownerPassword,
                ownerPin: ownerPin,
                locationId: useExistingLocation ? selectedLocationId : nil,
                locationName: useExistingLocation ? nil : locationName,
                squareLocationId: nil
            )
            
            let _: InitialSetupResponse = try await APIClient.shared.request(
                endpoint: .initialSetup,
                body: request
            )
            
            showSuccess = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Error de configuración"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    InitialSetupView(
        onSetupComplete: {},
        onSwitchToLogin: {}
    )
    .environmentObject(AuthManager.shared)
}
