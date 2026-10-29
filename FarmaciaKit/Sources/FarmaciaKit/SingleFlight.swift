import Foundation

// MARK: - Single Flight
//
// Coalesces concurrent calls into one in-flight operation: callers that arrive
// while it runs await the same result (or error). The next call after it ends
// starts a new one. Used for session refresh — the server rotates the token, so
// two refreshes racing with the same old token log the user out.

public actor SingleFlight<Value: Sendable> {
    private var current: Task<Value, Error>?

    public init() {}

    public func run(_ operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let current { return try await current.value }

        let task = Task { try await operation() }
        current = task
        defer {
            // Waiters resume after the task ends; only clear our own flight, not a newer one.
            if current == task { current = nil }
        }
        return try await task.value
    }
}
