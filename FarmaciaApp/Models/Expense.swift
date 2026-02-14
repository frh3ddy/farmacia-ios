import Foundation

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
    
    var color: String {
        switch self {
        case .rent: return "blue"
        case .utilities: return "yellow"
        case .payroll: return "green"
        case .insurance: return "purple"
        case .supplies: return "orange"
        case .marketing: return "pink"
        case .maintenance: return "gray"
        case .taxes: return "red"
        case .bankFees: return "indigo"
        case .software: return "cyan"
        case .professional: return "mint"
        case .other: return "secondary"
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
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amountDouble)) ?? "$\(amount)"
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
    
    var totalDouble: Double {
        Double(totalExpenses) ?? 0
    }
    
    var paidDouble: Double {
        Double(paidExpenses) ?? 0
    }
    
    var unpaidDouble: Double {
        Double(unpaidExpenses) ?? 0
    }
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
    
    var totalDouble: Double {
        Double(total) ?? 0
    }
    
    var percentageDouble: Double {
        Double(percentage) ?? 0
    }
}

struct MonthlyExpenseSummary: Decodable {
    let month: String
    let total: String
    let count: Int
    
    var totalDouble: Double {
        Double(total) ?? 0
    }
}

// MARK: - Expense Types Response

struct ExpenseTypesResponse: Decodable {
    let types: [String]
}
