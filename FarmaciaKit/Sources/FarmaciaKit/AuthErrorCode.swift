import Foundation

// MARK: - Auth Error Code
//
// Mirrors farmacia-ops auth/auth-error-code.ts. The app branches on the body's
// `code`; servers that predate it are matched on their exact message instead
// (never a substring — "Account not set up for device activation" is not a
// device failure).

public enum AuthErrorCode: String, Sendable {
    case pinInvalid = "PIN_INVALID"
    case tooManyAttempts = "TOO_MANY_ATTEMPTS"
    case credentialsInvalid = "CREDENTIALS_INVALID"
    case employeeInactive = "EMPLOYEE_INACTIVE"
    case activationNotAllowed = "ACTIVATION_NOT_ALLOWED"
    case deviceInvalid = "DEVICE_INVALID"
    case deviceRequired = "DEVICE_REQUIRED"
    case sessionInvalid = "SESSION_INVALID"
    case sessionExpired = "SESSION_EXPIRED"
    case sessionRequired = "SESSION_REQUIRED"

    private static let legacyMessages: [String: AuthErrorCode] = [
        "Session expired": .sessionExpired,
        "Invalid session": .sessionInvalid,
        "Session token required": .sessionRequired,
        "Invalid or deactivated device": .deviceInvalid,
        "Device token required in Authorization header": .deviceRequired,
        "PIN incorrecto": .pinInvalid,
        "Correo o contraseña incorrectos": .credentialsInvalid,
        "La cuenta del empleado está desactivada": .employeeInactive,
        "Account not set up for device activation. Contact administrator.": .activationNotAllowed,
    ]

    public static func resolve(body: Data) -> AuthErrorCode? {
        guard let response = try? JSONDecoder().decode(APIErrorResponse.self, from: body) else { return nil }
        return resolve(response)
    }

    public static func resolve(_ response: APIErrorResponse) -> AuthErrorCode? {
        if let code = response.code.flatMap(AuthErrorCode.init(rawValue:)) { return code }
        return response.message.flatMap { legacyMessages[$0] }
    }
}
