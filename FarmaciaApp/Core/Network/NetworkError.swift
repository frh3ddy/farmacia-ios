import Foundation

// MARK: - Network Error

enum NetworkError: LocalizedError {
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
    
    var errorDescription: String? {
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
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .sessionExpired, .pinRequired, .deviceNotActivated:
            return true
        case .accountLocked:
            return true // Wait for lockout to end
        case .networkUnavailable, .timeout:
            return true // Retry
        default:
            return false
        }
    }
}

// MARK: - API Response

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

struct EmptyResponse: Decodable {}

// MARK: - API Error Response

struct APIErrorResponse: Decodable {
    let success: Bool
    let error: String?
    let message: String?
    let statusCode: Int?
    let lockedUntil: String?
    
    var displayMessage: String {
        message ?? error ?? "Ocurrió un error desconocido"
    }
}
