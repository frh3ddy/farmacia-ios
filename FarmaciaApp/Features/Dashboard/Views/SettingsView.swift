import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false
    @State private var showDeactivateAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 12) {
                        Text(authManager.currentEmployee?.initials ?? "??")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentEmployee?.name ?? "User")
                                .font(.headline)
                            
                            Text(authManager.currentEmployee?.role.displayName ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Location Section
                Section("Current Location") {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(authManager.currentLocation?.name ?? "No Location")
                                .font(.headline)
                        }
                    }
                    
                    if authManager.availableLocations.count > 1 {
                        NavigationLink {
                            LocationSwitchView()
                        } label: {
                            Label("Switch Location", systemImage: "arrow.left.arrow.right")
                        }
                    }
                }
                
                // Session Info Section
                Section("Session") {
                    if let expiresAt = authManager.sessionExpiresAt {
                        HStack {
                            Text("Session Expires")
                            Spacer()
                            Text(expiresAt, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                // App Info Section
                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConfiguration.appVersion) (\(AppConfiguration.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(environmentName)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Device Section
                Section("Device") {
                    Button(role: .destructive) {
                        showDeactivateAlert = true
                    } label: {
                        Label("Deactivate Device", systemImage: "xmark.shield")
                    }
                    
                    Text("Deactivating will remove this device from Farmacia. You'll need owner or manager credentials to reactivate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out") {
                    Task {
                        await authManager.logout()
                    }
                }
            } message: {
                Text("You'll need to enter your PIN to log back in.")
            }
            .alert("Deactivate Device", isPresented: $showDeactivateAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Deactivate", role: .destructive) {
                    authManager.deactivateDevice()
                }
            } message: {
                Text("This will remove this device from Farmacia. All users will need to log in again after reactivation.")
            }
        }
    }
    
    private var environmentName: String {
        switch AppConfiguration.current {
        case .development: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
