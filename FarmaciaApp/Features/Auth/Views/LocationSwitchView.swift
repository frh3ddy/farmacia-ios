import SwiftUI

// MARK: - Location Switch View

struct LocationSwitchView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var switchingLocationId: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successLocationName = ""
    @State private var searchText = ""
    
    // Filtered locations based on search
    private var filteredLocations: [SessionLocation] {
        if searchText.isEmpty {
            return authManager.availableLocations
        }
        return authManager.availableLocations.filter { location in
            location.name.localizedCaseInsensitiveContains(searchText) ||
            location.role.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Check if we have multiple locations to warrant search
    private var showSearch: Bool {
        authManager.availableLocations.count > 3
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Current Location Header
                if let currentLocation = authManager.currentLocation {
                    currentLocationHeader(currentLocation)
                }
                
                Divider()
                
                // Search Bar (only if many locations)
                if showSearch {
                    searchBar
                }
                
                // Available Locations
                if authManager.availableLocations.isEmpty {
                    emptyStateView
                } else if authManager.availableLocations.count == 1 {
                    singleLocationView
                } else {
                    locationsList
                }
            }
            .navigationTitle("Cambiar Ubicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .alert("Error al Cambiar", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if showSuccess {
                    successOverlay
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Buscar ubicaciones...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Current Location Header
    
    private func currentLocationHeader(_ location: SessionLocation) -> some View {
        VStack(spacing: 12) {
            // Location Icon with animated pulse
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 70, height: 70)
                
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "building.2.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }
            
            // Location Name
            Text(location.name)
                .font(.title2)
                .fontWeight(.bold)
            
            // Role Badge
            HStack(spacing: 6) {
                Image(systemName: location.role.icon)
                    .font(.caption)
                Text(location.role.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(location.role.color.opacity(0.15))
            .foregroundStyle(location.role.color)
            .clipShape(.rect(cornerRadius: 12))
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Actualmente Activa")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Locations List
    
    private var locationsList: some View {
        List {
            Section {
                if filteredLocations.isEmpty {
                    noSearchResultsView
                } else {
                    ForEach(filteredLocations) { location in
                        let isCurrent = authManager.currentLocation?.id == location.id
                        let isSwitching = switchingLocationId == location.id
                        
                        Button {
                            Task {
                                await switchToLocation(location)
                            }
                        } label: {
                            LocationRow(
                                location: location,
                                isCurrent: isCurrent,
                                isSwitching: isSwitching
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isCurrent || switchingLocationId != nil)
                        .accessibilityLabel("\(location.name), \(location.role.displayName)")
                        .accessibilityHint(isCurrent ? "Ubicación actualmente activa" : "Doble toque para cambiar a esta ubicación")
                    }
                }
            } header: {
                HStack {
                    Text("Ubicaciones Disponibles")
                    Spacer()
                    Text("\(authManager.availableLocations.count)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selecciona una ubicación para cambiar tu lugar de trabajo actual.")
                    Text("Tu rol y permisos pueden variar según la ubicación.")
                        .foregroundStyle(.orange)
                }
                .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - No Search Results
    
    private var noSearchResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("No se encontraron ubicaciones")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Prueba con otro término de búsqueda")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "building.2")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            
            Text("Sin Ubicaciones Disponibles")
                .font(.headline)
            
            Text("No tienes acceso a ninguna ubicación.\nContacta a tu administrador para asistencia.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                dismiss()
            } label: {
                Text("Cerrar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 48)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Single Location View
    
    private var singleLocationView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
            }
            
            Text("¡Todo Listo!")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Solo tienes acceso a una ubicación,\nla cual ya está activa.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                dismiss()
            } label: {
                Text("Listo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                }
                
                Text("Cambiado a")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(successLocationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 20))
        }
        .transition(.opacity)
    }
    
    // MARK: - Switch Location
    
    private func switchToLocation(_ location: SessionLocation) async {
        // Haptic feedback - preparing to switch
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        
        switchingLocationId = location.id
        
        do {
            try await authManager.switchLocation(to: location.id)
            
            // Success haptic
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            // Show success animation
            successLocationName = location.name
            withAnimation(.easeInOut(duration: 0.3)) {
                showSuccess = true
            }
            
            // Wait a moment for user to see success
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            dismiss()
        } catch let error as NetworkError {
            // Error haptic
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            
            errorMessage = error.errorDescription ?? "Error al cambiar ubicación"
            showError = true
        } catch {
            // Error haptic
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            
            errorMessage = error.localizedDescription
            showError = true
        }
        
        switchingLocationId = nil
    }
    
}

// MARK: - Location Row

struct LocationRow: View {
    let location: SessionLocation
    let isCurrent: Bool
    let isSwitching: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Location Icon
            ZStack {
                Circle()
                    .fill(isCurrent ? Color.green.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 48, height: 48)
                
                if isSwitching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Image(systemName: isCurrent ? "building.2.fill" : "building.2")
                        .font(.system(size: 20))
                        .foregroundStyle(isCurrent ? Color.green : Color.secondary)
                }
            }
            
            // Location Info
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(isCurrent ? Color.green : Color.primary)
                
                // Role with icon
                HStack(spacing: 4) {
                    Image(systemName: location.role.icon)
                        .font(.caption2)
                    Text(location.role.displayName)
                        .font(.caption)
                }
                .foregroundStyle(location.role.color.opacity(isCurrent ? 1.0 : 0.8))
            }
            
            Spacer()
            
            // Status indicator
            if isCurrent {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Activa")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.green)
                }
            } else if !isSwitching {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(isCurrent ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSwitching)
    }
    
}

// MARK: - Preview

#Preview("Multiple Locations") {
    LocationSwitchView()
        .environmentObject(AuthManager.shared)
}

#Preview("Dark Mode") {
    LocationSwitchView()
        .environmentObject(AuthManager.shared)
        .preferredColorScheme(.dark)
}
