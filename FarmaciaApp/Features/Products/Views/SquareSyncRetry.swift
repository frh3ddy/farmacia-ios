import Foundation
import FarmaciaKit

// MARK: - Square Sync Retry

/// Retries one receiving's or adjustment's push to Square (owner only) and
/// returns what to tell the user. The API answers HTTP 200 even when the
/// retry fails, so the outcome comes from its `data`.
@MainActor
enum SquareSyncRetry {
    static func run(_ endpoint: APIEndpoint) async -> String {
        do {
            let response: RetrySquareSyncResponse = try await APIClient.shared.request(endpoint: endpoint)
            switch SquareSync.RetryOutcome(synced: response.data?.isSuccess ?? false, error: response.data?.error) {
            case .synced: return "Sincronizado con Square"
            case .failed(let message): return message
            }
        } catch {
            // Not queued offline (not replay-safe), so this is always a failure
            guard case .failed(let message) = SaveOutcome(error: error, fallback: "No se pudo sincronizar con Square") else {
                return "No se pudo sincronizar con Square"
            }
            return message
        }
    }
}
