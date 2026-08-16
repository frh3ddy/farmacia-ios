import Foundation
import Network

// MARK: - Network Monitor
//
// Single source of truth for "are we online" across the app, and the trigger
// that replays the offline write queue as soon as connectivity returns.

@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected = true

    /// Flips true exactly once per online→offline transition, so the root
    /// view can show a single info dialog instead of one per failed request.
    var justWentOffline = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.farmacia.network-monitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self?.handle(connected: connected)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func handle(connected: Bool) {
        let wasConnected = isConnected
        isConnected = connected

        if wasConnected, !connected {
            justWentOffline = true
        } else if !wasConnected, connected {
            Task { await OfflineQueueManager.shared.flush() }
        }
    }
}
