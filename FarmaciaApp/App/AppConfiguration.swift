import Foundation

// MARK: - App Configuration

enum AppConfiguration {
    
    // MARK: - Environment
    
    enum Environment {
        case development
        case staging
        case production
    }
    
    static var current: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    // MARK: - API Configuration
    
    // For physical device testing, replace with your Mac's local IP
    // Find it with: ifconfig | grep "inet " | grep -v 127.0.0.1
    // Example: "http://192.168.1.100:3000"
    private static let localServerIP = "localhost" // Change to your Mac's IP for physical device
    
    static var apiBaseURL: String {
        switch current {
        case .development:
            return "http://\(localServerIP):3000"
        case .staging:
            return "https://farmacia-api-staging.railway.app"
        case .production:
            return "https://farmacia-api.railway.app"
        }
    }
    
    // MARK: - Session Configuration
    
    static let sessionDurationSeconds: TimeInterval = 4 * 60 * 60 // 4 hours
    static let sessionRefreshThresholdSeconds: TimeInterval = 30 * 60 // 30 minutes before expiry
    
    // MARK: - PIN Configuration
    
    static let pinLength = 4
    static let maxPINLength = 6
    static let pinLockoutAttempts = 3
    static let pinLockoutDurationSeconds: TimeInterval = 5 * 60 // 5 minutes
    
    // MARK: - Keychain Configuration
    
    static let keychainServiceName = "com.farmacia.ios"
    static let deviceTokenKey = "deviceToken"
    static let employeeIdKey = "employeeId"
    
    // MARK: - App Info
    
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
