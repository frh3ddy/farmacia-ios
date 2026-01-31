import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Auth State

enum AuthState: Equatable {
    case loading
    case deviceNotActivated
    case needsPIN
    case authenticated
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AuthManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentEmployee: Employee?
    @Published private(set) var currentLocation: Location?
    @Published private(set) var availableLocations: [Location] = []
    @Published private(set) var sessionExpiresAt: Date?
    @Published var error: NetworkError?
    @Published var isLoading: Bool = false
    
    // MARK: - Properties
    
    private let keychain = KeychainManager.shared
    private let apiClient = APIClient.shared
    private var sessionRefreshTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        Task {
            await checkAuthStatus()
        }
    }
    
    // MARK: - Public Methods
    
    /// Check current authentication status
    func checkAuthStatus() async {
        authState = .loading
        
        // Check if device is activated
        guard let deviceToken = keychain.deviceToken else {
            authState = .deviceNotActivated
            return
        }
        
        // Set device token on API client
        apiClient.deviceToken = deviceToken
        
        // Device is activated, need PIN login
        authState = .needsPIN
    }
    
    /// Activate device with owner/manager credentials
    func activateDevice(
        email: String,
        password: String,
        deviceName: String,
        locationId: String
    ) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let request = DeviceActivationRequest(
            email: email,
            password: password,
            deviceName: deviceName,
            locationId: locationId,
            deviceType: "MOBILE" // iPad/iPhone
        )
        
        do {
            let response: DeviceActivationResponse = try await apiClient.request(
                endpoint: .deviceActivate,
                body: request
            )
            
            // Store device token in Keychain
            keychain.deviceToken = response.deviceToken
            apiClient.deviceToken = response.deviceToken
            
            // Update state
            authState = .needsPIN
        } catch let networkError as NetworkError {
            error = networkError
            throw networkError
        } catch {
            let networkError = NetworkError.unknown(error)
            self.error = networkError
            throw networkError
        }
    }
    
    /// Login with PIN
    func loginWithPIN(pin: String, locationId: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let request = PINLoginRequest(pin: pin, locationId: locationId)
        
        do {
            let response: PINLoginResponse = try await apiClient.request(
                endpoint: .pinLogin,
                body: request
            )
            
            // Store session token
            apiClient.sessionToken = response.sessionToken
            keychain.lastEmployeeId = response.employee.id
            
            // Update state
            currentEmployee = response.employee
            currentLocation = response.location
            availableLocations = response.availableLocations
            sessionExpiresAt = response.expiresAt
            
            // Start session refresh timer
            startSessionRefreshTimer()
            
            authState = .authenticated
        } catch let networkError as NetworkError {
            error = networkError
            throw networkError
        } catch {
            let networkError = NetworkError.unknown(error)
            self.error = networkError
            throw networkError
        }
    }
    
    /// Switch to different location
    func switchLocation(to locationId: String) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let request = SwitchLocationRequest(locationId: locationId)
        
        do {
            let response: SwitchLocationResponse = try await apiClient.request(
                endpoint: .switchLocation,
                body: request
            )
            
            // Update session token
            apiClient.sessionToken = response.sessionToken
            
            // Update state
            currentLocation = response.location
            sessionExpiresAt = response.expiresAt
        } catch let networkError as NetworkError {
            error = networkError
            throw networkError
        } catch {
            let networkError = NetworkError.unknown(error)
            self.error = networkError
            throw networkError
        }
    }
    
    /// Logout current session
    func logout() async {
        isLoading = true
        
        defer { 
            isLoading = false
            // Clear session regardless of API result
            clearSession()
        }
        
        // Try to logout on server (non-blocking)
        do {
            try await apiClient.requestVoid(endpoint: .logout)
        } catch {
            // Ignore logout errors - clear session anyway
            print("Logout API error: \(error)")
        }
    }
    
    /// Deactivate device (full reset)
    func deactivateDevice() {
        keychain.clearAll()
        apiClient.deviceToken = nil
        apiClient.sessionToken = nil
        clearSession()
        authState = .deviceNotActivated
    }
    
    // MARK: - Session Management
    
    private func clearSession() {
        stopSessionRefreshTimer()
        apiClient.sessionToken = nil
        currentEmployee = nil
        currentLocation = nil
        availableLocations = []
        sessionExpiresAt = nil
        authState = .needsPIN
    }
    
    private func startSessionRefreshTimer() {
        stopSessionRefreshTimer()
        
        // Check session every minute
        sessionRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSessionExpiry()
            }
        }
    }
    
    private func stopSessionRefreshTimer() {
        sessionRefreshTimer?.invalidate()
        sessionRefreshTimer = nil
    }
    
    private func checkSessionExpiry() {
        guard let expiresAt = sessionExpiresAt else { return }
        
        let timeRemaining = expiresAt.timeIntervalSinceNow
        
        if timeRemaining <= 0 {
            // Session expired
            clearSession()
        } else if timeRemaining <= AppConfiguration.sessionRefreshThresholdSeconds {
            // Session expiring soon - notify user
            // In a real app, you might want to refresh the session here
            print("Session expiring in \(Int(timeRemaining)) seconds")
        }
    }
    
    // MARK: - Helpers
    
    private func getOSVersion() -> String {
        #if os(iOS)
        return "iOS \(UIDevice.current.systemVersion)"
        #elseif os(macOS)
        return "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
        #else
        return "Unknown"
        #endif
    }
    
    // MARK: - Role Checking
    
    var isOwner: Bool {
        currentEmployee?.role == .owner
    }
    
    var isManager: Bool {
        currentEmployee?.role == .manager || isOwner
    }
    
    var canManageEmployees: Bool {
        isOwner
    }
    
    var canManageInventory: Bool {
        isManager
    }
    
    var canViewReports: Bool {
        currentEmployee?.role != .cashier
    }
    
    var canManageExpenses: Bool {
        currentEmployee?.role == .owner ||
        currentEmployee?.role == .manager ||
        currentEmployee?.role == .accountant
    }
}

// MARK: - Response Types

// Lightweight structs for device activation response (matches backend exactly)
struct ActivatedDevice: Decodable {
    let id: String
    let name: String
    let type: String
    let activatedAt: Date
}

struct ActivatedBy: Decodable {
    let id: String
    let name: String
}

struct ActivationLocation: Decodable {
    let id: String
    let name: String
}

struct DeviceActivationResponse: Decodable {
    let deviceToken: String
    let device: ActivatedDevice
    let location: ActivationLocation
    let activatedBy: ActivatedBy
}

struct PINLoginResponse: Decodable {
    let sessionToken: String
    let employee: Employee
    let location: Location
    let availableLocations: [Location]
    let expiresAt: Date
}

struct SwitchLocationResponse: Decodable {
    let sessionToken: String
    let location: Location
    let expiresAt: Date
}

struct CurrentUserResponse: Decodable {
    let employee: Employee
    let location: Location
    let availableLocations: [Location]
    let sessionExpiresAt: Date
}
