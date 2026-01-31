import SwiftUI

// MARK: - PIN Entry View

struct PINEntryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = PINEntryViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with employee selection
                headerSection
                
                Spacer()
                
                // PIN Display
                pinDisplaySection
                
                Spacer()
                
                // Number Pad
                numberPadSection
            }
            .padding()
            .background(Color(.systemBackground))
            .navigationTitle("Employee Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.showDeactivateAlert = true
                        } label: {
                            Label("Deactivate Device", systemImage: "xmark.shield")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showLocationPicker) {
                LocationPickerView(
                    locations: viewModel.locations,
                    selectedLocation: $viewModel.selectedLocation
                )
            }
            .alert("Deactivate Device", isPresented: $viewModel.showDeactivateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Deactivate", role: .destructive) {
                    authManager.deactivateDevice()
                }
            } message: {
                Text("This will remove this device from Farmacia. You'll need owner/manager credentials to reactivate.")
            }
            .alert("Login Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {
                    viewModel.clearPIN()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadLocations()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Location Selector
            Button {
                viewModel.showLocationPicker = true
            } label: {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.blue)
                    
                    Text(viewModel.selectedLocation?.name ?? "Select Location")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            
            Text("Enter your PIN to log in")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    // MARK: - PIN Display Section
    
    private var pinDisplaySection: some View {
        VStack(spacing: 24) {
            // PIN Dots
            HStack(spacing: 20) {
                ForEach(0..<AppConfiguration.pinLength, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.pin.count ? Color.blue : Color(.systemGray4))
                        .frame(width: 20, height: 20)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.pin.count)
                }
            }
            
            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    // MARK: - Number Pad Section
    
    private var numberPadSection: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 24) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        numberButton(number: number)
                    }
                }
            }
            
            // Bottom row: empty, 0, delete
            HStack(spacing: 24) {
                // Empty space
                Color.clear
                    .frame(width: 80, height: 80)
                
                // Zero
                numberButton(number: 0)
                
                // Delete
                deleteButton
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Number Button
    
    private func numberButton(number: Int) -> some View {
        Button {
            viewModel.appendDigit(number, authManager: authManager)
        } label: {
            Text("\(number)")
                .font(.largeTitle)
                .fontWeight(.medium)
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6))
                .cornerRadius(40)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.pin.count >= AppConfiguration.pinLength || viewModel.isLoading)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button {
            viewModel.deleteDigit()
        } label: {
            Image(systemName: "delete.left")
                .font(.title2)
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6))
                .cornerRadius(40)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.pin.isEmpty || viewModel.isLoading)
    }
}

// MARK: - PIN Entry View Model

@MainActor
class PINEntryViewModel: ObservableObject {
    @Published var pin: String = ""
    @Published var locations: [Location] = []
    @Published var selectedLocation: Location?
    @Published var isLoading: Bool = false
    @Published var showLocationPicker: Bool = false
    @Published var showDeactivateAlert: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private let apiClient = APIClient.shared
    
    func loadLocations() async {
        do {
            // Fetch locations from API
            let response: [Location] = try await apiClient.request(endpoint: .listLocations)
            locations = response
            // Auto-select first location if only one
            if locations.count == 1 {
                selectedLocation = locations[0]
            }
        } catch {
            print("Failed to load locations: \(error)")
            errorMessage = "Could not load locations"
            showError = true
        }
    }
    
    func appendDigit(_ digit: Int, authManager: AuthManager) {
        guard pin.count < AppConfiguration.pinLength else { return }
        pin += "\(digit)"
        
        // Auto-submit when PIN is complete
        if pin.count == AppConfiguration.pinLength {
            Task {
                await login(authManager: authManager)
            }
        }
    }
    
    func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }
    
    func clearPIN() {
        pin = ""
    }
    
    func login(authManager: AuthManager) async {
        guard let location = selectedLocation else {
            errorMessage = "Please select a location"
            showError = true
            clearPIN()
            return
        }
        
        isLoading = true
        
        do {
            try await authManager.loginWithPIN(pin: pin, locationId: location.id)
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Login failed"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - Location Picker View

struct LocationPickerView: View {
    let locations: [Location]
    @Binding var selectedLocation: Location?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(locations) { location in
                Button {
                    selectedLocation = location
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(location.name)
                                .font(.headline)
                            
                            if let address = location.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if selectedLocation?.id == location.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PINEntryView()
        .environmentObject(AuthManager.shared)
}
