import Foundation

// MARK: - Setup Status

struct SetupStatus: Codable {
    let needsSetup: Bool
    let hasEmployees: Bool
    let hasLocations: Bool
    let employeeCount: Int
    let locationCount: Int
}

struct SetupStatusResponse: Codable {
    let success: Bool
    let data: SetupStatus
}

// MARK: - Initial Setup Request

struct InitialSetupRequest: Encodable {
    let ownerName: String
    let ownerEmail: String
    let ownerPassword: String
    let ownerPin: String
    let locationName: String
    let squareLocationId: String?
}

// MARK: - Initial Setup Response

struct InitialSetupData: Codable {
    let owner: SetupOwner
    let location: SetupLocation
    let assignment: SetupAssignment
}

struct SetupOwner: Codable {
    let id: String
    let name: String
    let email: String?
}

struct SetupLocation: Codable {
    let id: String
    let name: String
}

struct SetupAssignment: Codable {
    let id: String
    let role: String
}

struct InitialSetupResponse: Codable {
    let success: Bool
    let message: String
    let data: InitialSetupData
}
