import Foundation

// MARK: - Network Error

public enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case encodingError(Error)
    case httpError(statusCode: Int, message: String?)
    case unauthorized
    case deviceNotActivated
    case sessionExpired
    case pinRequired
    case accountLocked(until: Date?)
    case networkUnavailable
    case timeout
    case serverError(message: String)
    case unknown(Error)
    case queuedForSync
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .noData:
            return "No se recibieron datos del servidor"
        case .decodingError(let error):
            return "Error al decodificar respuesta: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Error al codificar solicitud: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return message ?? "Error HTTP: \(statusCode)"
        case .unauthorized:
            return "Acceso no autorizado"
        case .deviceNotActivated:
            return "Dispositivo no activado"
        case .sessionExpired:
            return "La sesión ha expirado. Por favor inicia sesión de nuevo."
        case .pinRequired:
            return "Se requiere verificación de PIN"
        case .accountLocked(let until):
            if let until = until {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Cuenta bloqueada hasta \(formatter.string(from: until))"
            }
            return "La cuenta está temporalmente bloqueada"
        case .networkUnavailable:
            return "Conexión de red no disponible"
        case .timeout:
            return "La solicitud expiró"
        case .serverError(let message):
            return message
        case .unknown(let error):
            return error.localizedDescription
        case .queuedForSync:
            return "Sin conexión. Este cambio se guardó y se sincronizará automáticamente."
        case .cancelled:
            return "Solicitud cancelada"
        }
    }
    
    public var isRecoverable: Bool {
        switch self {
        case .sessionExpired, .pinRequired, .deviceNotActivated:
            return true
        case .accountLocked:
            return true // Wait for lockout to end
        case .networkUnavailable, .timeout, .queuedForSync:
            return true // Retry
        default:
            return false
        }
    }
}

// MARK: - From HTTP Response

extension NetworkError {
    /// The error for an HTTP response, or nil for 2xx.
    public static func from(statusCode: Int, body: Data) -> NetworkError? {
        let decoder = JSONDecoder()
        switch statusCode {
        case 200...299:
            return nil
        case 401, 429:
            guard let errorResponse = try? decoder.decode(APIErrorResponse.self, from: body) else {
                return statusCode == 401 ? .unauthorized : .httpError(statusCode: statusCode, message: nil)
            }
            switch AuthErrorCode.resolve(errorResponse) {
            case .sessionExpired, .sessionInvalid, .sessionRequired:
                return .sessionExpired
            case .deviceInvalid, .deviceRequired:
                return .deviceNotActivated
            case .tooManyAttempts:
                return .accountLocked(until: errorResponse.lockedUntil.flatMap(parseTimestamp))
            case .pinInvalid, .credentialsInvalid, .employeeInactive, .activationNotAllowed, nil:
                return .httpError(statusCode: statusCode, message: errorResponse.displayMessage)
            }
        case 403:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: body), errorResponse.lockedUntil != nil {
                return .accountLocked(until: errorResponse.lockedUntil.flatMap(parseTimestamp))
            }
            return .unauthorized
        case 400...499:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: body) {
                return .httpError(statusCode: statusCode, message: errorResponse.displayMessage)
            }
            return .httpError(statusCode: statusCode, message: nil)
        case 500...599:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: body) {
                return .serverError(message: errorResponse.displayMessage)
            }
            return .serverError(message: "Error interno del servidor")
        default:
            return .httpError(statusCode: statusCode, message: nil)
        }
    }

    /// The API's ISO timestamps carry milliseconds (JS toISOString); accept both forms.
    private static func parseTimestamp(_ value: String) -> Date? {
        let withMillis = ISO8601DateFormatter()
        withMillis.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withMillis.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

// MARK: - API Response

public struct APIResponse<T: Decodable>: Decodable {
    public let success: Bool
    public let data: T?
    public let error: String?
    public let message: String?
}

public struct EmptyResponse: Decodable {
    public init() {}
}

// MARK: - API Error Response

public struct APIErrorResponse: Decodable {
    public let success: Bool
    public let error: String?
    public let message: String?
    public let statusCode: Int?
    public let lockedUntil: String?
    /// Stable error code (AuthErrorCode raw values); absent from older servers.
    public let code: String?
    
    public var displayMessage: String {
        message ?? error ?? "Ocurrió un error desconocido"
    }
}
