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
    /// A positive adjustment for a product with no cost on record (UNIT_COST_REQUIRED).
    case unitCostRequired(message: String)
    /// A transfer the API refused with a stable code (`NetworkError.refusalCodes`).
    case refused(Refusal)

    public struct Refusal: Equatable, Sendable {
        public let code: String
        public let message: String
        /// The item the refusal names, when it names one.
        public let productId: String?
        /// INSUFFICIENT_STOCK: what the store has.
        public let available: Int?

        public init(code: String, message: String, productId: String?, available: Int?) {
            self.code = code
            self.message = message
            self.productId = productId
            self.available = available
        }
    }

    /// The transfer codes whose details the screen needs (which product, how many).
    public static let refusalCodes: Set<String> = [
        "NO_ITEMS", "TOO_MANY_ITEMS", "INVALID_QUANTITY", "DUPLICATE_PRODUCT", "SAME_LOCATION",
        "DESTINATION_NOT_CUT_OVER", "PRODUCT_NOT_SOLD_AT_LOCATION", "INSUFFICIENT_STOCK",
        "RECEIVE_ON_SEND_NOT_ALLOWED", "INVALID_ITEM", "LOCATION_NOT_CUT_OVER",
        "CLIENT_REQUEST_ID_REUSED",
    ]

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
        case .unitCostRequired(let message):
            return message
        case .refused(let refusal):
            return refusal.message
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
            if let refusal = refusal(from: body) { return refusal }
            return .unauthorized
        case 400...499:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: body) {
                // Code first; the exact message is what APIs before the code send
                if errorResponse.code == "UNIT_COST_REQUIRED"
                    || errorResponse.message == "Indica el costo unitario: este producto no tiene un costo anterior registrado." {
                    return .unitCostRequired(message: errorResponse.displayMessage)
                }
                if let refusal = refusal(from: body) { return refusal }
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

    private static func refusal(from body: Data) -> NetworkError? {
        guard let response = try? JSONDecoder().decode(APIErrorResponse.self, from: body),
              let code = response.code, refusalCodes.contains(code) else { return nil }
        return .refused(Refusal(code: code, message: response.displayMessage,
                                productId: response.productId, available: response.available))
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
    /// Only on errors the API builds by hand; NestJS's default exceptions omit it.
    public let success: Bool?
    public let error: String?
    public let message: String?
    public let statusCode: Int?
    public let lockedUntil: String?
    /// Stable error code (AuthErrorCode raw values); absent from older servers.
    public let code: String?
    /// Transfer refusals: the item named, and (INSUFFICIENT_STOCK) what the store has.
    public let productId: String?
    public let available: Int?
    
    public var displayMessage: String {
        message ?? error ?? "Ocurrió un error desconocido"
    }
}

extension NetworkError {
    /// A task cancelled (view left, search changed) rather than a failure to show.
    public static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if case .cancelled? = error as? NetworkError { return true }
        return false
    }
}

extension APIResponse {
    /// The payload of a 2xx response; throws `.noData` when it's missing, so a
    /// caller can't silently skip its success handling (or its error).
    public func requireData() throws -> T {
        guard let data else { throw NetworkError.noData }
        return data
    }
}
