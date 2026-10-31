import Foundation
import FarmaciaKit
import SwiftData

// MARK: - Offline Queue Manager
//
// Persists replay-safe writes that failed due to connectivity, and replays
// them in the order they were made once the network returns, each under the
// session of the employee who made it. What may be queued, who may replay it
// and what a failed replay means are FarmaciaKit's `OfflineReplay`; this
// manager only handles storage and delivery. Server-side idempotency keys
// (clientRequestId) are what make a replay safe.

@MainActor
@Observable
final class OfflineQueueManager {
    static let shared = OfflineQueueManager()

    /// Pending writes of the employee logged in (the ones a flush will send).
    private(set) var pendingCount = 0
    /// Names of other employees with writes waiting for them to log in on this device.
    private(set) var pendingForOthers: [String] = []
    private(set) var failedRequests: [QueuedRequest] = []

    private var modelContext: ModelContext?
    private var isFlushing = false

    private init() {}

    /// Initialize with SwiftData container. Call once at app startup.
    func configure(container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        modelContext = context
        cleanUpStoredItems()
        refresh()
    }

    /// Called by APIClient when a replay-safe write fails due to connectivity.
    /// Returns false if it couldn't be stored, so the caller reports the real error
    /// instead of telling the screen it was saved.
    func enqueue(method: String, path: String, bodyData: Data?) -> Bool {
        guard let context = modelContext,
              OfflineReplay.isReplaySafe(method: method, path: path),
              let employee = AuthManager.shared.currentEmployee else { return false }
        let item = QueuedRequest(
            method: method, path: path, bodyData: bodyData,
            summary: OfflineReplay.label(method: method, path: path),
            employeeId: employee.id, employeeName: employee.name
        )
        context.insert(item)
        do {
            try context.save()
        } catch {
            context.delete(item)
            return false
        }
        refresh()
        return true
    }

    /// Items an older version queued: delete any carrying credentials (PIN, password),
    /// and move unsafe or ownerless writes to the failed list for a person to review.
    private func cleanUpStoredItems() {
        guard let context = modelContext,
              let items = try? context.fetch(FetchDescriptor<QueuedRequest>()) else { return }
        for item in items {
            switch OfflineReplay.cleanup(method: item.method, path: item.path, employeeId: item.employeeId, status: item.status) {
            case .keep:
                break
            case .delete:
                context.delete(item)
            case .markFailed(let reason):
                item.status = "failed"
                item.lastError = reason
            }
        }
        try? context.save()
    }

    /// Replays pending requests oldest-first. Stops at the first connectivity
    /// failure (the rest stay queued for the next reconnect); any other
    /// failure (validation rejected it, or transient retries exhausted) is
    /// moved to `failedRequests` instead of being retried forever.
    func flush() async {
        // Without a session every replay 401s and would be marked failed for
        // good; wait for PIN login (RootView flushes on .authenticated).
        guard let context = modelContext, !isFlushing,
              APIClient.shared.sessionToken != nil else { return }
        isFlushing = true
        defer { isFlushing = false }

        let pendingStatus = "pending"
        let descriptor = FetchDescriptor<QueuedRequest>(
            predicate: #Predicate { $0.status == pendingStatus },
            sortBy: [SortDescriptor(\.queuedAt)]
        )
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return }
        // Only this employee's writes, under their own session; others wait for them.
        // Checked per item: the employee can change during the awaits of a long flush.
        for item in items {
            guard OfflineReplay.shouldReplay(itemEmployeeId: item.employeeId,
                                             currentEmployeeId: AuthManager.shared.currentEmployee?.id) else { continue }
            do {
                try await APIClient.shared.replay(method: item.method, path: item.path, bodyData: item.bodyData)
                context.delete(item)
            } catch {
                switch OfflineReplay.afterFailure(error) {
                case .stopAndKeep:
                    // Offline again, the session lapsed, or cancelled mid-flight:
                    // leave this and the rest queued for the next flush.
                    try? context.save()
                    refresh()
                    return
                case .markFailed:
                    item.status = "failed"
                    item.lastError = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
                }
            }
        }

        try? context.save()
        refresh()
    }

    /// User has reviewed a failed sync and wants it replayed.
    func retryFailed(_ item: QueuedRequest) {
        guard let context = modelContext, let employee = AuthManager.shared.currentEmployee else { return }
        item.employeeId = OfflineReplay.ownerAfterRetry(itemEmployeeId: item.employeeId, retriedBy: employee.id)
        item.employeeName = employee.name
        item.status = "pending"
        item.lastError = nil
        try? context.save()
        refresh()
        Task { await flush() }
    }

    /// User has reviewed a failed sync and chosen to discard it.
    func dismissFailed(_ item: QueuedRequest) {
        guard let context = modelContext else { return }
        context.delete(item)
        try? context.save()
        refresh()
    }

    /// Recount after the logged-in employee changes (whose writes are "pending" depends on it).
    func refresh() {
        guard let context = modelContext else { return }
        let pendingStatus = "pending"
        let pending = (try? context.fetch(
            FetchDescriptor<QueuedRequest>(predicate: #Predicate { $0.status == pendingStatus })
        )) ?? []
        let currentEmployeeId = AuthManager.shared.currentEmployee?.id
        let mine = pending.filter { OfflineReplay.shouldReplay(itemEmployeeId: $0.employeeId, currentEmployeeId: currentEmployeeId) }
        pendingCount = mine.count
        pendingForOthers = Array(Set(pending.filter { $0.employeeId != currentEmployeeId }.compactMap(\.employeeName))).sorted()

        let failedStatus = "failed"
        let failedDescriptor = FetchDescriptor<QueuedRequest>(
            predicate: #Predicate { $0.status == failedStatus },
            sortBy: [SortDescriptor(\.queuedAt)]
        )
        failedRequests = (try? context.fetch(failedDescriptor)) ?? []
    }
}
