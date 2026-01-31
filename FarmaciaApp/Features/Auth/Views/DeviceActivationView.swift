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
            .task {
                await viewModel.loadLocations()
            }
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
            
            // Location Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if viewModel.isLoadingLocations {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading locations...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if viewModel.locations.isEmpty {
                    Text("No locations available")
                        .foregroundColor(.red)
                        .font(.caption)
                } else {
                    Picker("Select Location", selection: $viewModel.selectedLocationId) {
                        Text("Select a location").tag("")
                        ForEach(viewModel.locations, id: \.id) { location in
                            Text(location.name).tag(location.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
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
    @Published var selectedLocationId: String = ""
    @Published var locations: [Location] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingLocations: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private let apiClient = APIClient.shared
    
    var isFormValid: Bool {
        !deviceName.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        !selectedLocationId.isEmpty
    }
    
    func loadLocations() async {
        isLoadingLocations = true
        
        do {
            // Backend returns locations as array in 'data' field
            let response: [Location] = try await apiClient.request(endpoint: .listLocations)
            locations = response
            // Auto-select first location if only one
            if locations.count == 1 {
                selectedLocationId = locations[0].id
            }
        } catch {
            print("Failed to load locations: \(error)")
            // For development, allow manual entry or use default
            errorMessage = "Could not load locations. Check backend connection."
            showError = true
        }
        
        isLoadingLocations = false
    }
    
    func activateDevice(authManager: AuthManager) async {
        guard !selectedLocationId.isEmpty else {
            errorMessage = "Please select a location"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            try await authManager.activateDevice(
                email: email,
                password: password,
                deviceName: deviceName,
                locationId: selectedLocationId
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
