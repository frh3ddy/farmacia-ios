import SwiftUI
import SwiftData

@main
struct FarmaciaApp: App {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([CachedProduct.self, SyncMetadata.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
            // Configure the shared cache manager
            ProductCacheManager.shared.configure(container: modelContainer)
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .modelContainer(modelContainer)
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
            
            Text("Cargando...")
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
