import Foundation

// MARK: - Retry Policy
//
// Retries a transient (server-side) failure a few times with exponential
// backoff before giving up. Connectivity failures are deliberately NOT
// retried here — retrying instantly with no network is pointless. Those go
// through OfflineQueueManager instead, replayed once the network returns.

public enum RetryPolicy {
    public static func withBackoff<T>(
        maxAttempts: Int = 3,
        baseDelay: Double = 2,
        operation: () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch let error as NetworkError {
                guard case .serverError = error, attempt < maxAttempts else { throw error }
                let seconds = baseDelay * pow(2.0, Double(attempt - 1)) // 2s, 4s, ...
                try await Task.sleep(for: .seconds(seconds)) // cancelled → CancellationError, no further attempts
                attempt += 1
            }
        }
    }
}
