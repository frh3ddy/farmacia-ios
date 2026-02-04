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
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Setup Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Setup Complete!", isPresented: $viewModel.showSuccess) {
                Button("Continue") {
                    onSetupComplete()
                }
            } message: {
                Text("Your account has been created. You can now log in.")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Set Up Your Pharmacy")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create your owner account and pharmacy location to get started")
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
                Label("Owner Account", systemImage: "person.fill")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    TextField("Your Name", text: $viewModel.ownerName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                    
                    TextField("Email", text: $viewModel.ownerEmail)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    SecureField("Password (min 6 characters)", text: $viewModel.ownerPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("PIN (4-6 digits)")
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
                            Text("Confirm PIN")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("Confirm", text: $viewModel.confirmPin)
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
                Label("Pharmacy Location", systemImage: "building.2.fill")
                    .font(.headline)
                
                TextField("Pharmacy Name", text: $viewModel.locationName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
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
                    Text("Complete Setup")
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
            Text("Already have an account? Log in")
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
    
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    
    var isFormValid: Bool {
        !ownerName.isEmpty &&
        ownerName.count >= 2 &&
        !ownerEmail.isEmpty &&
        ownerEmail.contains("@") &&
        ownerPassword.count >= 6 &&
        ownerPassword == confirmPassword &&
        ownerPin.count >= 4 &&
        ownerPin == confirmPin &&
        !locationName.isEmpty &&
        locationName.count >= 2
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
                locationName: locationName,
                squareLocationId: nil
            )
            
            let _: InitialSetupResponse = try await APIClient.shared.request(
                endpoint: .initialSetup,
                body: request
            )
            
            showSuccess = true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Setup failed"
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
