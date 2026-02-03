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

// MARK: - Session Types (lightweight, matches backend responses)

struct SessionEmployee: Equatable {
    let id: String
    let name: String
    let role: EmployeeRole
}

extension SessionEmployee {
    var initials: String {
        let components = name.split(separator: " ", omittingEmptySubsequences: true)
        let first = components.first?.first.map { String($0).uppercased() } ?? ""
        let second = components.dropFirst().first?.first.map { String($0).uppercased() } ?? ""
        return first + second
    }
}

struct SessionLocation: Equatable, Identifiable {
    let id: String
    let name: String
    let role: EmployeeRole
    
    init(id: String, name: String, role: EmployeeRole) {
        self.id = id
        self.name = name
        self.role = role
    }
    
    init(from pinLocation: PINLoginLocation) {
        self.id = pinLocation.locationId
        self.name = pinLocation.locationName
        self.role = EmployeeRole(rawValue: pinLocation.role) ?? .cashier
    }
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AuthManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentEmployee: SessionEmployee?
    @Published private(set) var currentLocation: SessionLocation?
    @Published private(set) var availableLocations: [SessionLocation] = []
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
    
    /// Validate and potentially refresh current session (call when app becomes active)
    func validateSession() async {
        guard authState == .authenticated, apiClient.sessionToken != nil else { return }
        
        // Check if session is expired or about to expire
        if let expiresAt = sessionExpiresAt {
            if expiresAt.timeIntervalSinceNow <= 0 {
                // Session expired
                clearSession()
                return
            } else if expiresAt.timeIntervalSinceNow <= AppConfiguration.sessionRefreshThresholdSeconds {
                // Session expiring soon - refresh
                await refreshSession()
            }
        }
    }
    
    /// Activate device with owner/manager credentials
    func activateDevice(
        email: String,
        password: String,
        deviceName: String
    ) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let request = DeviceActivationRequest(
            email: email,
            password: password,
            deviceName: deviceName,
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
    func loginWithPIN(pin: String, locationId: String? = nil) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // Backend only needs PIN - device token provides location context
        let request = PINLoginRequest(pin: pin, locationId: locationId ?? "")
        
        do {
            let response: PINLoginResponse = try await apiClient.request(
                endpoint: .pinLogin,
                body: request
            )
            
            // Store session token
            apiClient.sessionToken = response.sessionToken
            keychain.lastEmployeeId = response.employee.id
            
            // Convert response to session types
            let currentLoc = response.currentLocation.map { SessionLocation(from: $0) }
            
            // Determine role - use current location role or first accessible location role
            let employeeRole: EmployeeRole
            if let loc = currentLoc {
                employeeRole = loc.role
            } else if let firstLocation = response.accessibleLocations.first {
                employeeRole = EmployeeRole(rawValue: firstLocation.role) ?? .cashier
            } else {
                employeeRole = .cashier
            }
            
            // Update state
            currentEmployee = SessionEmployee(
                id: response.employee.id,
                name: response.employee.name,
                role: employeeRole
            )
            currentLocation = currentLoc
            availableLocations = response.accessibleLocations.map { SessionLocation(from: $0) }
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
            
            // Update state with new location
            currentLocation = SessionLocation(from: response.currentLocation)
            
            // Update employee role if it changed for this location
            if let employee = currentEmployee {
                currentEmployee = SessionEmployee(
                    id: employee.id,
                    name: employee.name,
                    role: currentLocation?.role ?? employee.role
                )
            }
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
            // Session expiring soon - refresh automatically
            print("Session expiring in \(Int(timeRemaining)) seconds - refreshing...")
            Task {
                await refreshSession()
            }
        }
    }
    
    /// Refresh the current session to extend expiry
    func refreshSession() async {
        do {
            let response: SessionRefreshResponse = try await apiClient.request(
                endpoint: .pinRefresh
            )
            
            // Update session token and expiry
            apiClient.sessionToken = response.sessionToken
            sessionExpiresAt = response.expiresAt
            
            print("Session refreshed, new expiry: \(response.expiresAt)")
        } catch let networkError as NetworkError {
            print("Failed to refresh session: \(networkError.localizedDescription)")
            // If refresh fails due to auth issues, clear session
            if case .unauthorized = networkError {
                clearSession()
            } else if case .sessionExpired = networkError {
                clearSession()
            }
        } catch {
            print("Failed to refresh session: \(error.localizedDescription)")
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

// Lightweight structs for PIN login response (matches backend exactly)
struct PINLoginEmployee: Decodable {
    let id: String
    let name: String
}

struct PINLoginLocation: Decodable {
    let locationId: String
    let locationName: String
    let role: String
}

struct PINLoginResponse: Decodable {
    let sessionToken: String
    let employee: PINLoginEmployee
    let currentLocation: PINLoginLocation?  // Optional - may be null if no assignment
    let accessibleLocations: [PINLoginLocation]
    let expiresAt: Date
}

struct SessionRefreshResponse: Decodable {
    let sessionToken: String
    let expiresAt: Date
}

struct SwitchLocationResponse: Decodable {
    let previousLocation: PINLoginLocation?
    let currentLocation: PINLoginLocation
}

struct CurrentUserResponse: Decodable {
    let employee: Employee
    let location: Location
    let availableLocations: [Location]
    let sessionExpiresAt: Date
}

