import SwiftUI

// MARK: - Device Activation View

struct DeviceActivationView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = DeviceActivationViewModel()
    @State private var showSetup = false
    @State private var needsSetup = false
    @State private var checkingSetup = true
    
    var body: some View {
        Group {
            if checkingSetup {
                loadingView
            } else if showSetup && needsSetup {
                InitialSetupView(
                    onSetupComplete: {
                        showSetup = false
                        needsSetup = false
                    },
                    onSwitchToLogin: {
                        showSetup = false
                    }
                )
            } else {
                activationView
            }
        }
        .task {
            await checkSetupStatus()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Verificando estado...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Activation View
    
    private var activationView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    headerSection
                    
                    // Activation Form
                    formSection
                    
                    // Activate Button
                    activateButton
                    
                    // Setup Link (if needed)
                    if needsSetup {
                        setupLink
                    }
                    
                    // Help Text
                    helpSection
                }
                .padding(24)
            }
            .navigationTitle("Configurar Dispositivo")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error de Activación", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Check Setup Status
    
    private func checkSetupStatus() async {
        do {
            let response: SetupStatusResponse = try await APIClient.shared.request(
                endpoint: .setupStatus
            )
            needsSetup = response.data.needsSetup
            showSetup = response.data.needsSetup
        } catch {
            // If we can't check, assume setup is done
            needsSetup = false
        }
        checkingSetup = false
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Farmacia")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Activa este dispositivo para comenzar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // Device Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre del Dispositivo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Ej: iPad Mostrador Principal", text: $viewModel.deviceName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            
            Divider()
            
            Text("Credenciales de Dueño/Gerente")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("Correo Electrónico")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("owner@example.com", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Contraseña")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField("Ingresa contraseña", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Activate Button
    
    private var activateButton: some View {
        Button {
            Task {
                await viewModel.activateDevice(authManager: authManager)
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Activar Dispositivo")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isFormValid ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
            .fontWeight(.semibold)
        }
        .disabled(!viewModel.isFormValid || viewModel.isLoading)
    }
    
    // MARK: - Setup Link
    
    private var setupLink: some View {
        VStack(spacing: 12) {
            Divider()
            
            Text("¿Primera vez usando Farmacia?")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showSetup = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Configura Tu Farmacia")
                }
                .font(.headline)
                .foregroundColor(.green)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(spacing: 12) {
            Text("La activación del dispositivo es única")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                Text("Solo dueños y gerentes pueden activar dispositivos")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Device Activation View Model

@MainActor
class DeviceActivationViewModel: ObservableObject {
    @Published var deviceName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    var isFormValid: Bool {
        !deviceName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6
    }
    
    func activateDevice(authManager: AuthManager) async {
        isLoading = true
        
        do {
            try await authManager.activateDevice(
                email: email,
                password: password,
                deviceName: deviceName
            )
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Error de activación"
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
    DeviceActivationView()
        .environmentObject(AuthManager.shared)
}
