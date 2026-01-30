import SwiftUI

// MARK: - Device Activation View

struct DeviceActivationView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = DeviceActivationViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and Title
                    headerSection
                    
                    // Activation Form
                    formSection
                    
                    // Activate Button
                    activateButton
                    
                    // Help Text
                    helpSection
                }
                .padding(24)
            }
            .navigationTitle("Setup Device")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Activation Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
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
            
            Text("Activate this device to get started")
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
                Text("Device Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("e.g., Main Counter iPad", text: $viewModel.deviceName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            
            Divider()
            
            Text("Owner/Manager Credentials")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Email
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
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
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField("Enter password", text: $viewModel.password)
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
                    Text("Activate Device")
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
    
    // MARK: - Help Section
    
    private var helpSection: some View {
        VStack(spacing: 12) {
            Text("Device activation is a one-time setup")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                Text("Only owners and managers can activate devices")
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
            errorMessage = error.errorDescription ?? "Activation failed"
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
