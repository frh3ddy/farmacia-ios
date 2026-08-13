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
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentEmployee?.name ?? "Usuario")
                                .font(.headline)
                            
                            Text(authManager.currentEmployee?.role.rawValue.capitalized ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.currentLocation?.name ?? "Sin Ubicación")
                                .font(.headline)
                            
                            if let role = authManager.currentLocation?.role {
                                HStack(spacing: 4) {
                                    Image(systemName: role.icon)
                                        .font(.caption2)
                                    Text(role.displayName)
                                        .font(.caption)
                                }
                                .foregroundStyle(role.color)
                            }
                        }
                        
                        Spacer()
                        
                        // Active indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Activa")
                                .font(.caption)
                        }
                        .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                    
                    if authManager.availableLocations.count > 1 {
                        NavigationLink {
                            LocationSwitchView()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(.blue)
                                Text("Cambiar Ubicación")
                                Spacer()
                                Text("\(authManager.availableLocations.count) disponibles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Ubicación Actual")
                } footer: {
                    if authManager.availableLocations.count > 1 {
                        Text("Tu rol y permisos pueden variar en otras ubicaciones.")
                    }
                }
                
                // Session Info Section
                Section("Sesión") {
                    if let expiresAt = authManager.sessionExpiresAt {
                        HStack {
                            Text("La Sesión Expira")
                            Spacer()
                            Text(expiresAt, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        showLogoutAlert = true
                    } label: {
                        Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                
                // App Info Section
                Section("Aplicación") {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text("\(AppConfiguration.appVersion) (\(AppConfiguration.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Ambiente")
                        Spacer()
                        Text(environmentName)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Device Section
                Section("Dispositivo") {
                    Button(role: .destructive) {
                        showDeactivateAlert = true
                    } label: {
                        Label("Desactivar Dispositivo", systemImage: "xmark.shield")
                    }
                    
                    Text("Desactivar eliminará este dispositivo de Farmacia. Necesitarás credenciales de dueño o gerente para reactivarlo.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
            .alert("Cerrar Sesión", isPresented: $showLogoutAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Cerrar Sesión") {
                    Task {
                        await authManager.logout()
                    }
                }
            } message: {
                Text("Necesitarás ingresar tu PIN para volver a iniciar sesión.")
            }
            .alert("Desactivar Dispositivo", isPresented: $showDeactivateAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Desactivar", role: .destructive) {
                    authManager.deactivateDevice()
                }
            } message: {
                Text("Esto eliminará este dispositivo de Farmacia. Todos los usuarios necesitarán iniciar sesión después de la reactivación.")
            }
        }
    }
    
    private var environmentName: String {
        switch AppConfiguration.current {
        case .development: return "Desarrollo"
        case .staging: return "Pruebas"
        case .production: return "Producción"
        }
    }
    
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
