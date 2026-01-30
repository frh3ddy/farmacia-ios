import SwiftUI

@main
struct FarmaciaApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
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
