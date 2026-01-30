import SwiftUI

// MARK: - Location Switch View

struct LocationSwitchView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(authManager.availableLocations) { location in
                    Button {
                        Task {
                            await switchToLocation(location)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let address = location.address {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if authManager.currentLocation?.id == location.id {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || authManager.currentLocation?.id == location.id)
                }
            }
            .navigationTitle("Switch Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Switch Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func switchToLocation(_ location: Location) async {
        isLoading = true
        
        do {
            try await authManager.switchLocation(to: location.id)
            dismiss()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Failed to switch location"
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
    LocationSwitchView()
        .environmentObject(AuthManager.shared)
}
