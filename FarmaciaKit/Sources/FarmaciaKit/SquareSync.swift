import Foundation

// MARK: - Square Sync
//
// Receivings and adjustments push their stock change to Square and record
// squareSynced / squareSyncError. When the push fails, the owner can retry it:
// POST /inventory/{receive,adjustments}/:id/retry-square-sync (OWNER only).
// The retry answers HTTP 200 even when it fails, with { data: { synced, error } }.

public enum SquareSync {
    /// A push to Square that failed and hasn't succeeded since.
    public static func failed(synced: Bool?, error: String?) -> Bool {
        synced != true && error != nil
    }

    /// Matches the API's @Roles('OWNER') on both retry routes.
    public static func canRetry(isOwner: Bool) -> Bool {
        isOwner
    }

    public enum RetryOutcome: Equatable, Sendable {
        case synced
        case failed(String)

        /// From the retry's `data`, not its HTTP status.
        public init(synced: Bool, error: String?) {
            guard !synced else {
                self = .synced
                return
            }
            let reason = error.map { ": \($0)" } ?? ""
            self = .failed("No se pudo sincronizar con Square\(reason)")
        }
    }
}
