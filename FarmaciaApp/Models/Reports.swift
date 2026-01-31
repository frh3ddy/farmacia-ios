import Foundation

// MARK: - Dashboard Report

struct DashboardReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let sales: SalesSummary
    let inventory: InventorySummary
    let adjustments: AdjustmentsSummary
    let receivings: ReceivingsSummary
    let operatingExpenses: OperatingExpensesSummary
    let netProfit: NetProfitSummary
}

// MARK: - Report Period

struct ReportPeriod: Decodable {
    let startDate: String
    let endDate: String
}

// MARK: - Sales Summary

struct SalesSummary: Decodable {
    let totalRevenue: String
    let totalCOGS: String
    let grossProfit: String
    let grossMarginPercent: String  // Backend returns as String
    let totalUnitsSold: Int
    let totalSales: Int
}

// MARK: - Inventory Summary

struct InventorySummary: Decodable {
    let totalUnits: Int
    let totalValue: String
    let totalProducts: Int
    let averageCostPerUnit: String
    let aging: AgingSummary?
}

struct AgingBucket: Decodable {
    let units: Int
    let value: String
}

struct AgingSummary: Decodable {
    let under30Days: AgingBucket
    let days30to60: AgingBucket
    let days60to90: AgingBucket
    let over90Days: AgingBucket
}

// MARK: - Adjustments Summary

struct AdjustmentsSummary: Decodable {
    let totalAdjustments: Int
    let totalLoss: String
    let totalGain: String
    let netImpact: String
}

// MARK: - Receivings Summary

struct ReceivingsSummary: Decodable {
    let totalReceivings: Int
    let totalQuantity: Int
    let totalCost: String
}

// MARK: - Operating Expenses Summary

struct OperatingExpensesSummary: Decodable {
    let total: String
    let byType: [ExpenseByType]
    let shrinkage: String
}

struct ExpenseByType: Decodable {
    let type: String
    let amount: String
    let percentage: String?  // Optional since some contexts may not have it
}

// MARK: - Net Profit Summary

struct NetProfitSummary: Decodable {
    let amount: String
    let marginPercent: String  // Backend returns as String
}

// MARK: - COGS Report

struct COGSReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let totalCOGS: String
    let totalUnitsSold: Int
    let averageCostPerUnit: String
    let byProduct: [ProductCOGS]?
    let byCategory: [CategoryCOGS]?
}

struct ProductCOGS: Decodable {
    let productId: String
    let productName: String
    let unitsSold: Int
    let totalCOGS: String
    let averageCost: String
}

struct CategoryCOGS: Decodable {
    let categoryId: String?
    let categoryName: String
    let unitsSold: Int
    let totalCOGS: String
    let averageCost: String
}

// MARK: - Valuation Report

struct ValuationReport: Decodable {
    let locationId: String?
    let productId: String?
    let totalUnits: Int
    let totalValue: String
    let averageCostPerUnit: String
    let batches: [BatchValuation]?
    let byProduct: [ProductValuation]?
}

struct BatchValuation: Decodable {
    let batchId: String
    let quantity: Int
    let unitCost: String
    let totalValue: String
    let receivedAt: String
    let age: Int // days
}

struct ProductValuation: Decodable {
    let productId: String
    let productName: String
    let totalUnits: Int
    let totalValue: String
    let averageCost: String
    let batchCount: Int
}

// MARK: - Profit Margin Report

struct ProfitMarginReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let totalRevenue: String
    let totalCOGS: String
    let grossProfit: String
    let grossMarginPercent: String  // Backend returns as String
    let byProduct: [ProductProfitMargin]?
}

struct ProductProfitMargin: Decodable {
    let productId: String
    let productName: String
    let revenue: String
    let cogs: String
    let grossProfit: String
    let marginPercent: String  // Backend returns as String
    let unitsSold: Int
}

// MARK: - Profit & Loss Report

struct ProfitLossReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let revenue: RevenueSummary
    let costOfGoodsSold: String
    let grossProfit: GrossProfitSummary
    let operatingExpenses: OperatingExpenses
    let netProfit: NetProfit
}

struct RevenueSummary: Decodable {
    let totalSales: String
    let returns: String?
    let netRevenue: String
}

struct GrossProfitSummary: Decodable {
    let amount: String
    let marginPercent: String  // Backend returns as String
}

struct OperatingExpenses: Decodable {
    let total: String
    let breakdown: [ExpenseBreakdown]
}

struct ExpenseBreakdown: Decodable {
    let type: String
    let amount: String
    let percentage: String  // Backend returns as String
}

struct NetProfit: Decodable {
    let amount: String
    let marginPercent: String  // Backend returns as String
}

// MARK: - Adjustment Impact Report

struct AdjustmentImpactReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let totalAdjustments: Int
    let totalLoss: String
    let totalGain: String
    let netImpact: String
    let shrinkageRate: String  // Backend returns as String
    let byType: [AdjustmentTypeImpact]
    let byProduct: [ProductAdjustmentImpact]?
}

struct AdjustmentTypeImpact: Decodable {
    let type: String
    let count: Int
    let totalQuantity: Int
    let totalCost: String
    let percentOfTotal: String  // Backend returns as String
}

struct ProductAdjustmentImpact: Decodable {
    let productId: String
    let productName: String
    let adjustmentCount: Int
    let totalQuantity: Int
    let totalCost: String
}

// MARK: - Receiving Summary Report

struct ReceivingSummaryReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let totalReceivings: Int
    let totalQuantity: Int
    let totalCost: String
    let averageCostPerUnit: String
    let bySupplier: [SupplierReceivingSummary]?
    let byProduct: [ProductReceivingSummary]?
}

struct SupplierReceivingSummary: Decodable {
    let supplierId: String?
    let supplierName: String
    let receivingCount: Int
    let totalQuantity: Int
    let totalCost: String
}

struct ProductReceivingSummary: Decodable {
    let productId: String
    let productName: String
    let receivingCount: Int
    let totalQuantity: Int
    let totalCost: String
    let averageCost: String
}
