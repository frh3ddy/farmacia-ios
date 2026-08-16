import SwiftUI
import SwiftData

@main
struct FarmaciaApp: App {
    @StateObject private var authManager = AuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    let modelContainer: ModelContainer
    
    init() {
        // Shared URL cache for product image bytes (raw network data).
        // Default URLCache is small; product photos benefit from a larger
        // disk budget so scrolling back never re-downloads.
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,   // 32 MB in-memory
            diskCapacity: 256 * 1024 * 1024     // 256 MB on disk
        )

        do {
            let schema = Schema([CachedProduct.self, SyncMetadata.self, QueuedRequest.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: config)
            // Configure the shared cache manager
            ProductCacheManager.shared.configure(container: modelContainer)
            OfflineQueueManager.shared.configure(container: modelContainer)
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
                    // Covers the case where writes were queued last session
                    // while offline, and the app is relaunched already online
                    // — NetworkMonitor's own flush only fires on a live
                    // offline→online transition, which won't happen here.
                    await OfflineQueueManager.shared.flush()
                }
            }
        }
    }
}

// MARK: - Root View (Navigation Controller)

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @Bindable private var networkMonitor = NetworkMonitor.shared
    @Bindable private var offlineQueue = OfflineQueueManager.shared
    @State private var showSyncIssues = false

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
        .onAppear {
            // WhatsApp-style: tapping anywhere outside a text input
            // dismisses the keyboard and resigns field focus globally.
            KeyboardDismissInstaller.install()
        }
        .safeAreaInset(edge: .top) {
            if authManager.authState == .authenticated {
                OfflineSyncBanner(
                    isOffline: !networkMonitor.isConnected,
                    pendingCount: offlineQueue.pendingCount,
                    failedCount: offlineQueue.failedRequests.count,
                    onTapFailed: { showSyncIssues = true }
                )
            }
        }
        .alert("Sin conexión", isPresented: $networkMonitor.justWentOffline) {
            Button("OK") {}
        } message: {
            Text("Tus cambios se guardarán en este dispositivo y se sincronizarán automáticamente en cuanto vuelva la conexión.")
        }
        .sheet(isPresented: $showSyncIssues) {
            OfflineSyncIssuesView(items: offlineQueue.failedRequests, onDismiss: offlineQueue.dismissFailed)
        }
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
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environmentObject(AuthManager.shared)
}
