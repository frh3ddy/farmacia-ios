import Foundation

// MARK: - Save Outcome
//
// What a form does when its save throws: close as saved (queued offline — the
// connectivity banner says it'll sync) or stay open showing why it failed,
// the API's own reason when it gave one.

public enum SaveOutcome: Equatable, Sendable {
    case saved
    case failed(String)
    case costRequired(String)

    public init(error: Error, fallback: String) {
        switch error {
        case NetworkError.queuedForSync:
            self = .saved
        case NetworkError.unitCostRequired(let message):
            self = .costRequired(message)
        case let error as NetworkError:
            self = .failed(error.errorDescription ?? fallback)
        default:
            self = .failed(fallback)
        }
    }
}
