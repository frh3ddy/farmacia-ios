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
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP Error: \(statusCode)"
        case .unauthorized:
            return "Unauthorized access"
        case .deviceNotActivated:
            return "Device is not activated"
        case .sessionExpired:
            return "Session has expired. Please login again."
        case .pinRequired:
            return "PIN verification required"
        case .accountLocked(let until):
            if let until = until {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Account locked until \(formatter.string(from: until))"
            }
            return "Account is temporarily locked"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .timeout:
            return "Request timed out"
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
        message ?? error ?? "An unknown error occurred"
    }
}
