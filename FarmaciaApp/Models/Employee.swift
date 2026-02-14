import Foundation

// MARK: - Employee Role

enum EmployeeRole: String, Codable, CaseIterable {
    case owner = "OWNER"
    case manager = "MANAGER"
    case cashier = "CASHIER"
    case accountant = "ACCOUNTANT"
    
    var displayName: String {
        switch self {
        case .owner: return "Dueño"
        case .manager: return "Gerente"
        case .cashier: return "Cajero"
        case .accountant: return "Contador"
        }
    }
    
    var permissions: Set<Permission> {
        switch self {
        case .owner:
            return Set(Permission.allCases)
        case .manager:
            return [
                .readEmployees,
                .adjustInventory, .receiveInventory, .readInventory,
                .createExpense, .readExpense, .updateExpense,
                .viewAllReports
            ]
        case .cashier:
            return [.readInventory]
        case .accountant:
            return [
                .readInventory,
                .createExpense, .readExpense, .updateExpense, .deleteExpense,
                .viewAllReports
            ]
        }
    }
}

// MARK: - Permission

enum Permission: String, CaseIterable {
    // Employee management
    case createEmployee
    case readEmployees
    case updateEmployee
    case deleteEmployee
    
    // Inventory management
    case adjustInventory
    case receiveInventory
    case readInventory
    
    // Expense management
    case createExpense
    case readExpense
    case updateExpense
    case deleteExpense
    
    // Reports
    case viewAllReports
}

// MARK: - Employee (matches backend response)

struct Employee: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String?
    let isActive: Bool
    let hasPIN: Bool
    let lastLoginAt: Date?
    let assignments: [EmployeeAssignment]?
    
    // Computed properties
    var displayName: String { name }
    
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
    
    // Get the primary role from assignments
    var primaryRole: EmployeeRole {
        // Return highest role from assignments
        if let assignments = assignments, !assignments.isEmpty {
            if assignments.contains(where: { $0.role == .owner }) { return .owner }
            if assignments.contains(where: { $0.role == .manager }) { return .manager }
            if assignments.contains(where: { $0.role == .accountant }) { return .accountant }
            return assignments[0].role
        }
        return .cashier
    }
    
    func hasPermission(_ permission: Permission) -> Bool {
        primaryRole.permissions.contains(permission)
    }
}

// MARK: - Employee Assignment (from list endpoint)

struct EmployeeAssignment: Codable, Identifiable, Equatable {
    let locationId: String
    let locationName: String
    let role: EmployeeRole
    
    var id: String { locationId }
}

// MARK: - Employee Detail (full employee from GET /employees/:id)

struct EmployeeDetail: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String?
    let isActive: Bool
    let hasPIN: Bool
    let failedPinAttempts: Int
    let lockedUntil: Date?
    let lastLoginAt: Date?
    let createdAt: Date
    let assignments: [EmployeeDetailAssignment]
    
    var displayName: String { name }
    
    var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
    
    var isLocked: Bool {
        if let lockedUntil = lockedUntil {
            return lockedUntil > Date()
        }
        return false
    }
    
    var primaryRole: EmployeeRole {
        if let first = assignments.first {
            return first.role
        }
        return .cashier
    }
}

// MARK: - Employee Detail Assignment

struct EmployeeDetailAssignment: Codable, Identifiable, Equatable {
    let id: String
    let locationId: String
    let locationName: String
    let role: EmployeeRole
    let isActive: Bool
    let assignedAt: Date
}

// MARK: - Legacy Location Assignment (for backward compatibility)

struct LocationAssignment: Codable, Identifiable, Equatable {
    let id: String
    let locationId: String
    let isDefault: Bool
    let assignedAt: Date
    let location: Location?
}

// MARK: - API Request/Response Types

struct CreateEmployeeRequest: Encodable {
    let name: String
    let email: String?
    let pin: String?
    let locationId: String
    let role: EmployeeRole
}

struct UpdateEmployeeRequest: Encodable {
    let name: String?
    let email: String?
    let isActive: Bool?
}

struct SetPINRequest: Encodable {
    let pin: String
}

// MARK: - Employee List Response

struct EmployeeListResponse: Decodable {
    let success: Bool
    let count: Int
    let data: [Employee]
}

// MARK: - Employee Detail Response

struct EmployeeDetailResponse: Decodable {
    let success: Bool
    let data: EmployeeDetail
}

// MARK: - Created Employee (response from POST /employees)

struct CreatedEmployee: Decodable {
    let id: String
    let name: String
    let email: String?
    let isActive: Bool
    let hasPIN: Bool
    let hasPassword: Bool?
    let createdAt: Date
    let assignments: [CreatedEmployeeAssignment]
}

struct CreatedEmployeeAssignment: Decodable {
    let locationId: String
    let locationName: String
    let role: EmployeeRole
    let isActive: Bool
}

// MARK: - Create Employee Response

struct CreateEmployeeResponse: Decodable {
    let success: Bool
    let message: String
    let data: CreatedEmployee
}

// MARK: - Simple Success Response

struct EmployeeActionResponse: Decodable {
    let success: Bool
    let message: String
}

