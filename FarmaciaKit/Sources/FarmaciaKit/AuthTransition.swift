import Foundation

// MARK: - Auth Transition
//
// What a refused request means for the signed-in state. Any request can learn
// that the server ended the session or revoked the device, not just the auth
// screens, so APIClient asks this after every refusal.

public enum AuthTransition: Equatable, Sendable {
    case none
    case endSession
    case deactivateDevice

    /// - Parameters:
    ///   - requestSessionToken: the session token the refused request was sent with.
    ///   - currentSessionToken: the session token the app holds now. When they differ the
    ///     token was rotated by a refresh while the request was in flight, so the refusal
    ///     is about a token that's already gone.
    public static func after(_ code: AuthErrorCode?, requestSessionToken: String?, currentSessionToken: String?) -> AuthTransition {
        switch code {
        case .deviceInvalid, .deviceRequired:
            return .deactivateDevice
        case .sessionExpired, .sessionInvalid, .sessionRequired, .employeeInactive:
            guard let requestSessionToken, requestSessionToken == currentSessionToken else { return .none }
            return .endSession
        case .pinInvalid, .tooManyAttempts, .credentialsInvalid, .activationNotAllowed, nil:
            return .none
        }
    }
}
