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
                        Text(String(authManager.currentEmployee?.name.prefix(2).uppercased() ?? "??"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentEmployee?.name ?? "User")
                                .font(.headline)
                            
                            Text(authManager.currentEmployee?.role.rawValue.capitalized ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Location Section
                Section {
                    HStack(spacing: 12) {
                        // Location icon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentLocation?.name ?? "No Location")
                                .font(.headline)
                            
                            if let role = authManager.currentLocation?.role {
                                HStack(spacing: 4) {
                                    Image(systemName: roleIcon(for: role))
                                        .font(.caption2)
                                    Text(role.displayName)
                                        .font(.caption)
                                }
                                .foregroundColor(roleColor(for: role))
                            }
                        }
                        
                        Spacer()
                        
                        // Active indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(.caption)
                        }
                        .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                    
                    if authManager.availableLocations.count > 1 {
                        NavigationLink {
                            LocationSwitchView()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundColor(.blue)
                                Text("Switch Location")
                                Spacer()
                                Text("\(authManager.availableLocations.count) available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Current Location")
                } footer: {
                    if authManager.availableLocations.count > 1 {
                        Text("Your role and permissions may differ at other locations.")
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
    
    private func roleIcon(for role: EmployeeRole) -> String {
        switch role {
        case .owner: return "crown.fill"
        case .manager: return "person.badge.key.fill"
        case .accountant: return "dollarsign.circle.fill"
        case .cashier: return "cart.fill"
        }
    }
    
    private func roleColor(for role: EmployeeRole) -> Color {
        switch role {
        case .owner: return .purple
        case .manager: return .blue
        case .accountant: return .green
        case .cashier: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
