import Foundation
import FarmaciaKit
import SwiftUI

// MARK: - Expense Type

enum ExpenseType: String, Codable, CaseIterable {
    case rent = "RENT"
    case utilities = "UTILITIES"
    case payroll = "PAYROLL"
    case insurance = "INSURANCE"
    case supplies = "SUPPLIES"
    case marketing = "MARKETING"
    case maintenance = "MAINTENANCE"
    case taxes = "TAXES"
    case bankFees = "BANK_FEES"
    case software = "SOFTWARE"
    case professional = "PROFESSIONAL"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .rent: return "Renta"
        case .utilities: return "Servicios"
        case .payroll: return "Nómina"
        case .insurance: return "Seguro"
        case .supplies: return "Insumos"
        case .marketing: return "Publicidad"
        case .maintenance: return "Mantenimiento"
        case .taxes: return "Impuestos"
        case .bankFees: return "Comisiones Bancarias"
        case .software: return "Software"
        case .professional: return "Servicios Profesionales"
        case .other: return "Otro"
        }
    }
    
    var icon: String {
        switch self {
        case .rent: return "building.2"
        case .utilities: return "bolt"
        case .payroll: return "person.3"
        case .insurance: return "shield"
        case .supplies: return "shippingbox"
        case .marketing: return "megaphone"
        case .maintenance: return "wrench"
        case .taxes: return "building.columns"
        case .bankFees: return "banknote"
        case .software: return "desktopcomputer"
        case .professional: return "briefcase"
        case .other: return "ellipsis.circle"
        }
    }
    
    /// Category identity color (not a status).
    var color: Color {
        switch self {
        case .rent: .blue
        case .utilities: .yellow
        case .payroll: .green
        case .insurance: .purple
        case .supplies: .orange
        case .marketing: .pink
        case .maintenance: .gray
        case .taxes: .red
        case .bankFees: .indigo
        case .software: .cyan
        case .professional: .mint
        case .other: .secondary
        }
    }
}

// MARK: - Expense

struct Expense: Codable, Identifiable {
    let id: String
    let locationId: String
    let type: ExpenseType
    let amount: String
    let date: Date
    let description: String?
    let vendor: String?
    let reference: String?
    let isPaid: Bool
    let paidAt: Date?
    let notes: String?
    let createdBy: String?
    let createdAt: Date
    let location: Location?
    
    var amountDouble: Double {
        Double(amount) ?? 0
    }
    
    /// MXN only — the backend's Expense model has no currency field.
    var formattedAmount: String {
        ReportFormat.currency(amount)
    }
}

// MARK: - Expense Responses

struct ExpenseCreateResponse: Decodable {
    let success: Bool
    let message: String
    let data: Expense
}

struct ExpenseListResponse: Decodable {
    let success: Bool
    let count: Int
    let data: [Expense]
}

struct ExpenseGetResponse: Decodable {
    let success: Bool
    let data: Expense
}

struct ExpenseSummaryResponse: Decodable {
    let success: Bool
    let data: ExpenseSummary
}

struct ExpenseSummary: Decodable {
    let period: ExpensePeriod?
    let locationId: String?
    let totals: ExpenseTotals
    let byType: [ExpenseTypeSummary]
    let byMonth: [MonthlyExpenseSummary]?
    
    // Convenience accessors
    var totalExpenses: String { totals.totalExpenses }
    var expenseCount: Int { totals.expenseCount }
    var paidExpenses: String { totals.paidExpenses }
    var unpaidExpenses: String { totals.unpaidExpenses }
}

struct ExpenseTotals: Decodable {
    let totalExpenses: String
    let expenseCount: Int
    let paidExpenses: String
    let unpaidExpenses: String
}

struct ExpensePeriod: Decodable {
    let startDate: Date?
    let endDate: Date?
}

struct ExpenseTypeSummary: Decodable {
    let type: ExpenseType
    let total: String
    let count: Int
    let percentage: String
}

struct MonthlyExpenseSummary: Decodable {
    let month: String
    let total: String
    let count: Int
}

// MARK: - Expense Types Response

struct ExpenseTypesResponse: Decodable {
    let types: [String]
}

// MARK: - Payment status

extension Expense {
    var paymentLabel: String { isPaid ? "Pagado" : "No pagado" }
    var paymentTone: Tone { isPaid ? .positive : .caution }
    var paymentIcon: String { isPaid ? "checkmark.circle.fill" : "clock" }
}
