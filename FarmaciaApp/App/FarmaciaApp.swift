import SwiftUI

@main
struct FarmaciaApp: App {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Validate session when app becomes active
                Task {
                    await authManager.validateSession()
                }
            }
        }
    }
}

// MARK: - Root View (Navigation Controller)

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                LoadingView()
                
            case .deviceNotActivated:
                DeviceActivationView()
                
            case .needsPIN:
                PINEntryView()
                
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authManager.authState)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AuthManager.shared)
}
