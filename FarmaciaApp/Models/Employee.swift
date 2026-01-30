import Foundation

// MARK: - Employee Role

enum EmployeeRole: String, Codable, CaseIterable {
    case owner = "OWNER"
    case manager = "MANAGER"
    case cashier = "CASHIER"
    case accountant = "ACCOUNTANT"
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .manager: return "Manager"
        case .cashier: return "Cashier"
        case .accountant: return "Accountant"
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

// MARK: - Employee

struct Employee: Codable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String?
    let role: EmployeeRole
    let isActive: Bool
    let pinSet: Bool
    let failedPinAttempts: Int?
    let lockedUntil: Date?
    let lastLoginAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let locationAssignments: [LocationAssignment]?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let firstInitial = firstName.prefix(1).uppercased()
        let lastInitial = lastName.prefix(1).uppercased()
        return "\(firstInitial)\(lastInitial)"
    }
    
    var isLocked: Bool {
        if let lockedUntil = lockedUntil {
            return lockedUntil > Date()
        }
        return false
    }
    
    func hasPermission(_ permission: Permission) -> Bool {
        role.permissions.contains(permission)
    }
}

// MARK: - Location Assignment

struct LocationAssignment: Codable, Identifiable, Equatable {
    let id: String
    let locationId: String
    let isDefault: Bool
    let assignedAt: Date
    let location: Location?
}
