import Foundation

// MARK: - Device Type

enum DeviceType: String, Codable {
    case fixed = "FIXED"
    case mobile = "MOBILE"
    
    var displayName: String {
        switch self {
        case .fixed: return "POS Fijo"
        case .mobile: return "Dispositivo Móvil"
        }
    }
}

// MARK: - Device

struct Device: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let deviceType: DeviceType
    let osVersion: String
    let appVersion: String
    let isActive: Bool
    let activatedBy: String?
    let activatedAt: Date
    let lastSeenAt: Date?
    let locationId: String?
    let location: Location?
    
    var isOnline: Bool {
        guard let lastSeen = lastSeenAt else { return false }
        // Consider device online if seen in last 5 minutes
        return Date().timeIntervalSince(lastSeen) < 300
    }
}
