import Foundation

// MARK: - API Client

final class APIClient {
    
    // MARK: - Singleton
    
    static let shared = APIClient()
    
    // MARK: - Properties
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // Auth tokens (managed by AuthManager)
    var deviceToken: String?
    var sessionToken: String?
    
    // MARK: - Initialization
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: configuration)
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        // Note: Backend returns camelCase keys, not snake_case
        // self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        // Note: Backend expects camelCase keys, not snake_case
        // self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Public Methods
    
    /// Performs an API request with automatic token handling
    func request<T: Decodable>(
        endpoint: APIEndpoint,
        body: Encodable? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> T {
        let request = try buildRequest(
            endpoint: endpoint,
            body: body,
            queryParams: queryParams
        )
        
        return try await perform(request)
    }
    
    /// Performs an API request that returns void
    func requestVoid(
        endpoint: APIEndpoint,
        body: Encodable? = nil,
        queryParams: [String: String]? = nil
    ) async throws {
        let request = try buildRequest(
            endpoint: endpoint,
            body: body,
            queryParams: queryParams
        )
        
        let _: EmptyResponse = try await perform(request)
    }
    
    /// Uploads an image via multipart/form-data
    func uploadImage<T: Decodable>(
        endpoint: APIEndpoint,
        imageData: Data,
        filename: String = "image.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> T {
        let urlString = AppConfiguration.apiBaseURL + endpoint.path
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("FarmaciaApp/\(AppConfiguration.appVersion)", forHTTPHeaderField: "User-Agent")
        
        // Auth headers
        if endpoint.requiresDeviceToken, let deviceToken = deviceToken {
            request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        }
        if endpoint.requiresSessionToken, let sessionToken = sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Session-Token")
        }
        
        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        return try await perform(request)
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(
        endpoint: APIEndpoint,
        body: Encodable?,
        queryParams: [String: String]?
    ) throws -> URLRequest {
        // Build URL
        var urlString = AppConfiguration.apiBaseURL + endpoint.path
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            var components = URLComponents(string: urlString)
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            urlString = components?.url?.absoluteString ?? urlString
        }
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("FarmaciaApp/\(AppConfiguration.appVersion)", forHTTPHeaderField: "User-Agent")
        
        // Auth headers
        if endpoint.requiresDeviceToken, let deviceToken = deviceToken {
            request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        }
        
        if endpoint.requiresSessionToken, let sessionToken = sessionToken {
            request.setValue(sessionToken, forHTTPHeaderField: "X-Session-Token")
        }
        
        // Body
        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }
        
        return request
    }
    
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.networkUnavailable
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(error)
            }
        } catch {
            throw NetworkError.unknown(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        
        // Log for debugging
        #if DEBUG
        print("[\(request.httpMethod ?? "?")] \(request.url?.absoluteString ?? "")")
        print("Status: \(httpResponse.statusCode)")
        if let bodyString = String(data: data, encoding: .utf8) {
            print("Response: \(bodyString.prefix(500))")
        }
        #endif
        
        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            // Try to parse error response for more details
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                if errorResponse.message?.contains("session") == true {
                    throw NetworkError.sessionExpired
                }
                if errorResponse.message?.contains("device") == true {
                    throw NetworkError.deviceNotActivated
                }
            }
            throw NetworkError.unauthorized
        case 403:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                if errorResponse.lockedUntil != nil {
                    let formatter = ISO8601DateFormatter()
                    let date = errorResponse.lockedUntil.flatMap { formatter.date(from: $0) }
                    throw NetworkError.accountLocked(until: date)
                }
            }
            throw NetworkError.unauthorized
        case 400...499:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NetworkError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.displayMessage
                )
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: nil)
        case 500...599:
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverError(message: errorResponse.displayMessage)
            }
            throw NetworkError.serverError(message: "Error interno del servidor")
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: nil)
        }
        
        // Decode response
        do {
            // First, try direct decoding (for responses like {success, message} without data wrapper)
            return try decoder.decode(T.self, from: data)
        } catch {
            // If direct decode fails, try wrapped response format {success, data: T}
            do {
                let wrappedResponse = try decoder.decode(APIResponse<T>.self, from: data)
                if wrappedResponse.success, let responseData = wrappedResponse.data {
                    return responseData
                } else if !wrappedResponse.success, let error = wrappedResponse.error ?? wrappedResponse.message {
                    // Only throw error if success is false
                    throw NetworkError.serverError(message: error)
                }
                // If success is true but no data, fall through to error
            } catch let networkError as NetworkError {
                throw networkError
            } catch {
                // Both decoding attempts failed
            }
            
            throw NetworkError.decodingError(error)
        }
    }
}

// MARK: - Request Bodies

struct DeviceActivationRequest: Encodable {
    let email: String
    let password: String
    let deviceName: String
    let deviceType: String
}

struct PINLoginRequest: Encodable {
    let pin: String
    let locationId: String
}

struct SwitchLocationRequest: Encodable {
    let locationId: String
}

// Employee request types are defined in Employee.swift

struct ReceiveInventoryRequest: Encodable {
    let locationId: String
    let productId: String
    let quantity: Int
    let unitCost: Double
    let supplierId: String?
    let invoiceNumber: String?
    let purchaseOrderId: String?
    let batchNumber: String?
    let expiryDate: String?  // Date-only string in YYYY-MM-DD format
    let manufacturingDate: String?  // Date-only string in YYYY-MM-DD format
    let receivedBy: String?
    let notes: String?
    let syncToSquare: Bool?
    // Optional selling price update
    let sellingPrice: Double?
    let syncPriceToSquare: Bool?
}

struct CreateAdjustmentRequest: Encodable {
    let locationId: String
    let productId: String
    let type: String
    let quantity: Int
    let reason: String?
    let notes: String?
    let unitCost: Double?
    let effectiveDate: String?  // Date-only string in YYYY-MM-DD format
    let adjustedBy: String?
    let syncToSquare: Bool?
}

struct QuickAdjustmentRequest: Encodable {
    let locationId: String
    let productId: String
    let quantity: Int
    let reason: String?
    let notes: String?
    let syncToSquare: Bool?
}

struct CreateExpenseRequest: Encodable {
    let locationId: String
    let type: String
    let amount: Double
    let date: String  // Date-only string in YYYY-MM-DD format
    let description: String?
    let vendor: String?
    let reference: String?
    let isPaid: Bool?
    let paidAt: Date?
    let notes: String?
    let createdBy: String?
}

struct UpdateExpenseRequest: Encodable {
    let type: String?
    let amount: Double?
    let date: String?  // Date-only string in YYYY-MM-DD format
    let description: String?
    let vendor: String?
    let reference: String?
    let isPaid: Bool?
    let paidAt: Date?
    let notes: String?
}
