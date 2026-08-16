import Foundation
import SwiftData

// MARK: - Offline Queue Manager
//
// Persists mutating requests that failed due to connectivity, and replays
// them in the order they were made once the network returns. No business
// logic here — just storage + replay, mirroring the role ProductCacheManager
// plays for the product cache. Server-side idempotency keys are what make
// replay safe for delta operations; this manager only handles delivery.

@MainActor
@Observable
final class OfflineQueueManager {
    static let shared = OfflineQueueManager()

    private(set) var pendingCount = 0
    private(set) var failedRequests: [QueuedRequest] = []

    private var modelContext: ModelContext?
    private var isFlushing = false

    private init() {}

    /// Initialize with SwiftData container. Call once at app startup.
    func configure(container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        modelContext = context
        refresh()
    }

    /// Called by APIClient when a mutating request fails due to connectivity.
    func enqueue(method: String, path: String, bodyData: Data?, summary: String) {
        guard let context = modelContext else { return }
        context.insert(QueuedRequest(method: method, path: path, bodyData: bodyData, summary: summary))
        try? context.save()
        refresh()
    }

    /// Replays pending requests oldest-first. Stops at the first connectivity
    /// failure (the rest stay queued for the next reconnect); any other
    /// failure (validation rejected it, or transient retries exhausted) is
    /// moved to `failedRequests` instead of being retried forever.
    func flush() async {
        guard let context = modelContext, !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        let pendingStatus = "pending"
        let descriptor = FetchDescriptor<QueuedRequest>(
            predicate: #Predicate { $0.status == pendingStatus },
            sortBy: [SortDescriptor(\.queuedAt)]
        )
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }

        for item in items {
            do {
                try await APIClient.shared.replay(method: item.method, path: item.path, bodyData: item.bodyData)
                context.delete(item)
            } catch let error as NetworkError {
                switch error {
                case .networkUnavailable, .timeout:
                    // Offline again mid-flush — leave this and the rest queued.
                    try? context.save()
                    refresh()
                    return
                default:
                    item.status = "failed"
                    item.lastError = error.errorDescription
                }
            } catch {
                item.status = "failed"
                item.lastError = error.localizedDescription
            }
        }

        try? context.save()
        refresh()
    }

    /// User has reviewed a failed sync and chosen to discard it.
    func dismissFailed(_ item: QueuedRequest) {
        guard let context = modelContext else { return }
        context.delete(item)
        try? context.save()
        refresh()
    }

    private func refresh() {
        guard let context = modelContext else { return }
        let pendingStatus = "pending"
        pendingCount = (try? context.fetchCount(
            FetchDescriptor<QueuedRequest>(predicate: #Predicate { $0.status == pendingStatus })
        )) ?? 0

        let failedStatus = "failed"
        let failedDescriptor = FetchDescriptor<QueuedRequest>(
            predicate: #Predicate { $0.status == failedStatus },
            sortBy: [SortDescriptor(\.queuedAt)]
        )
        failedRequests = (try? context.fetch(failedDescriptor)) ?? []
    }
}
