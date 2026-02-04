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
                .foregroundColor(.secondary)
            
            TextField("Search locations...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
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
                    .foregroundColor(.blue)
            }
            
            // Location Name
            Text(location.name)
                .font(.title2)
                .fontWeight(.bold)
            
            // Role Badge
            HStack(spacing: 6) {
                Image(systemName: roleIcon(for: location.role))
                    .font(.caption)
                Text(location.role.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(roleColor(for: location.role).opacity(0.15))
            .foregroundColor(roleColor(for: location.role))
            .cornerRadius(12)
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Currently Active")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                        .accessibilityHint(isCurrent ? "Currently active location" : "Double tap to switch to this location")
                    }
                }
            } header: {
                HStack {
                    Text("Available Locations")
                    Spacer()
                    Text("\(authManager.availableLocations.count)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select a location to switch your current working location.")
                    Text("Your role and permissions may vary by location.")
                        .foregroundColor(.orange)
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
                .foregroundColor(.secondary)
            
            Text("No locations found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Try a different search term")
                .font(.caption)
                .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
            }
            
            Text("No Locations Available")
                .font(.headline)
            
            Text("You don't have access to any locations.\nContact your administrator for assistance.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                dismiss()
            } label: {
                Text("Dismiss")
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
                    .foregroundColor(.green)
            }
            
            Text("You're All Set!")
                .font(.title3)
                .fontWeight(.bold)
            
            Text("You only have access to one location,\nwhich is already active.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                dismiss()
            } label: {
                Text("Done")
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
                        .foregroundColor(.green)
                }
                
                Text("Switched to")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(successLocationName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
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
            
            errorMessage = error.errorDescription ?? "Failed to switch location"
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
    
    // MARK: - Helpers
    
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
                        .foregroundColor(isCurrent ? .green : .secondary)
                }
            }
            
            // Location Info
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundColor(isCurrent ? .green : .primary)
                
                // Role with icon
                HStack(spacing: 4) {
                    Image(systemName: roleIcon(for: location.role))
                        .font(.caption2)
                    Text(location.role.displayName)
                        .font(.caption)
                }
                .foregroundColor(roleColor(for: location.role).opacity(isCurrent ? 1.0 : 0.8))
            }
            
            Spacer()
            
            // Status indicator
            if isCurrent {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.green)
                }
            } else if !isSwitching {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .opacity(isCurrent ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSwitching)
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

#Preview("Multiple Locations") {
    LocationSwitchView()
        .environmentObject(AuthManager.shared)
}

#Preview("Dark Mode") {
    LocationSwitchView()
        .environmentObject(AuthManager.shared)
        .preferredColorScheme(.dark)
}
