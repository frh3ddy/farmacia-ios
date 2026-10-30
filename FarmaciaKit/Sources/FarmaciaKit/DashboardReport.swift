import Foundation

// Dashboard response (GET /inventory/reports/dashboard). Moved from the app so
// decoding per role is tested.

// MARK: - Dashboard Report

public struct DashboardReport: Decodable {
    public let period: ReportPeriod
    public let locationId: String?
    public let sales: SalesSummary
    public let inventory: InventorySummary
    public let adjustments: AdjustmentsSummary
    public let receivings: ReceivingsSummary
    // Sent only to OWNER and ACCOUNTANT, the roles that may open the P&L report.
    public let operatingExpenses: OperatingExpensesSummary?
    public let netProfit: NetProfitSummary?

    enum CodingKeys: String, CodingKey {
        case period, locationId, sales, inventory
        case adjustments, receivings
        case operatingExpenses, netProfit
    }
}

// MARK: - Report Period

public struct ReportPeriod: Decodable {
    public let startDate: String?
    public let endDate: String?
}

// MARK: - Sales Summary

// Cost-based fields (nil for a CASHIER, who sees nothing the pharmacy paid) are optional.

public struct SalesSummary: Decodable {
    public let totalRevenue: String
    public let totalCOGS: String?
    public let grossProfit: String?
    public let grossMarginPercent: String?
    public let totalUnitsSold: Int
    public let totalSales: Int
}

// MARK: - Inventory Summary

public struct InventorySummary: Decodable {
    public let totalUnits: Int
    public let totalValue: String?
    public let totalProducts: Int
    public let averageCostPerUnit: String?
    public let aging: AgingSummary?
}

public struct AgingBucket: Decodable {
    public let units: Int
    public let value: String
}

public struct AgingSummary: Decodable {
    public let under30Days: AgingBucket
    public let days30to60: AgingBucket
    public let days60to90: AgingBucket
    public let over90Days: AgingBucket
}

// MARK: - Adjustments Summary

public struct AdjustmentsSummary: Decodable {
    public let totalAdjustments: Int
    public let totalLoss: String?
    public let totalGain: String?
    public let netImpact: String?
}

// MARK: - Receivings Summary

public struct ReceivingsSummary: Decodable {
    public let totalReceivings: Int
    public let totalQuantity: Int
    public let totalCost: String?
}

// MARK: - Operating Expenses Summary

public struct OperatingExpensesSummary: Decodable {
    public let total: String
    public let byType: [ExpenseByType]
    public let shrinkage: String
}

public struct ExpenseByType: Decodable {
    public let type: String
    public let amount: String
    public let percentage: String?
}
