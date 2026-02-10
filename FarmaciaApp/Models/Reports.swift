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
    let startDate: String?
    let endDate: String?
}

// MARK: - Sales Summary

struct SalesSummary: Decodable {
    let totalRevenue: String
    let totalCOGS: String
    let grossProfit: String
    let grossMarginPercent: String
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
    let percentage: String?
}

// MARK: - Net Profit Summary

struct NetProfitSummary: Decodable {
    let amount: String
    let marginPercent: String
}

// MARK: - COGS Report
// Backend returns: { period, locationId, summary: { totalCOGS, totalRevenue, grossProfit, grossMarginPercent, totalUnitsSold, totalSales }, byProduct, byCategory }

struct COGSReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let summary: COGSSummary
    let byProduct: [ProductCOGS]
    let byCategory: [CategoryCOGS]?
}

struct COGSSummary: Decodable {
    let totalCOGS: String
    let totalRevenue: String
    let grossProfit: String
    let grossMarginPercent: String
    let totalUnitsSold: Int
    let totalSales: Int
}

struct ProductCOGS: Decodable, Identifiable {
    let productId: String
    let productName: String
    let sku: String?
    let unitsSold: Int
    let totalCost: String
    let totalRevenue: String
    let grossProfit: String
    let marginPercent: String
    
    var id: String { productId }
}

struct CategoryCOGS: Decodable, Identifiable {
    let categoryId: String?
    let categoryName: String
    let totalCost: String
    let totalRevenue: String
    let grossProfit: String
    
    var id: String { categoryId ?? categoryName }
}

// MARK: - Valuation Report
// Backend returns: { asOfDate, locationId, summary: { totalUnits, totalValue, totalProducts, averageCostPerUnit }, byProduct, agingSummary }

struct ValuationReport: Decodable {
    let asOfDate: Date?
    let locationId: String?
    let summary: ValuationSummary
    let byProduct: [ProductValuation]
    let agingSummary: AgingSummary?
}

struct ValuationSummary: Decodable {
    let totalUnits: Int
    let totalValue: String
    let totalProducts: Int
    let averageCostPerUnit: String
}

struct ProductValuation: Decodable, Identifiable {
    let productId: String
    let productName: String
    let sku: String?
    let totalQuantity: Int  // Note: backend uses totalQuantity, not totalUnits
    let totalValue: String
    let averageCost: String
    let batches: [BatchValuation]?
    
    var id: String { productId }
}

struct BatchValuation: Decodable, Identifiable {
    let batchId: String
    let quantity: Int
    let unitCost: String
    let value: String
    let receivedAt: Date
    let age: Int  // days since received
    
    // Batch-level metadata (from linked InventoryReceiving)
    let source: String?            // "PURCHASE", "OPENING_BALANCE", "ADJUSTMENT"
    let batchNumber: String?       // Lot/batch number from supplier
    let expiryDate: Date?          // Product expiration date
    let manufacturingDate: Date?   // Manufacturing date if known
    let invoiceNumber: String?     // Supplier invoice number
    let supplierId: String?        // Supplier ID
    let supplierName: String?      // Supplier display name
    
    var id: String { batchId }
    
    /// True if batch has an expiry date that is within the given days threshold
    func expiresWithin(days: Int) -> Bool {
        guard let expiry = expiryDate else { return false }
        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? Int.max
        return daysUntilExpiry <= days
    }
    
    /// True if batch is already expired
    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }
    
    /// Days until expiry (nil if no expiry date, negative if expired)
    var daysUntilExpiry: Int? {
        guard let expiry = expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
    }
    
    /// Human-readable source label
    var sourceLabel: String {
        switch source {
        case "PURCHASE": return "Purchase"
        case "OPENING_BALANCE": return "Opening Balance"
        case "ADJUSTMENT": return "Adjustment"
        default: return source ?? "Unknown"
        }
    }
}

// MARK: - Profit Margin Report
// Backend returns: { period, locationId, overallMargin, byProduct, trends }

struct ProfitMarginReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let overallMargin: String
    let byProduct: [ProductProfitMargin]
    let trends: [MarginTrend]?
}

struct ProductProfitMargin: Decodable, Identifiable {
    let productId: String
    let productName: String
    let revenue: String
    let cost: String
    let profit: String
    let marginPercent: String
    let unitsSold: Int
    
    var id: String { productId }
}

struct MarginTrend: Decodable, Identifiable {
    let date: String
    let revenue: String
    let cost: String
    let profit: String
    let marginPercent: String
    
    var id: String { date }
}

// MARK: - Profit & Loss Report
// Backend returns: { period, locationId, revenue, costOfGoodsSold, grossProfit, operatingExpenses, netProfit, summary }

struct ProfitLossReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let revenue: PLRevenue
    let costOfGoodsSold: PLCostOfGoodsSold
    let grossProfit: PLGrossProfit
    let operatingExpenses: PLOperatingExpenses
    let netProfit: PLNetProfit
    let summary: PLSummary?
}

struct PLRevenue: Decodable {
    let sales: String
    let total: String
}

struct PLCostOfGoodsSold: Decodable {
    let productCosts: String
    let total: String
}

struct PLGrossProfit: Decodable {
    let amount: String
    let marginPercent: String
}

struct PLOperatingExpenses: Decodable {
    let byType: [ExpenseBreakdown]
    let shrinkage: String
    let total: String
}

struct ExpenseBreakdown: Decodable, Identifiable {
    let type: String
    let amount: String
    let percentage: String
    
    var id: String { type }
}

struct PLNetProfit: Decodable {
    let amount: String
    let marginPercent: String
}

struct PLSummary: Decodable {
    let totalRevenue: String
    let totalCOGS: String
    let grossProfit: String
    let grossMarginPercent: String
    let totalOperatingExpenses: String
    let netProfit: String
    let netMarginPercent: String
    let salesCount: Int
    let expenseCount: Int
}

// MARK: - Adjustment Impact Report
// Backend returns: { period, locationId, summary: { totalAdjustments, totalLoss, totalGain, netImpact }, byType, byProduct }

struct AdjustmentImpactReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let summary: AdjustmentImpactSummary
    let byType: [AdjustmentTypeImpact]
    let byProduct: [ProductAdjustmentImpact]?
}

struct AdjustmentImpactSummary: Decodable {
    let totalAdjustments: Int
    let totalLoss: String
    let totalGain: String
    let netImpact: String
}

struct AdjustmentTypeImpact: Decodable, Identifiable {
    let type: String
    let count: Int
    let totalQuantity: Int
    let totalCost: String
    
    var id: String { type }
}

struct ProductAdjustmentImpact: Decodable, Identifiable {
    let productId: String
    let productName: String
    let adjustmentCount: Int
    let totalQuantity: Int
    let totalLoss: String
    let totalGain: String
    let netImpact: String
    
    var id: String { productId }
}

// MARK: - Receiving Summary Report
// Backend returns: { period, locationId, summary: { totalReceivings, totalQuantity, totalCost, averageCostPerUnit }, bySupplier, byProduct }

struct ReceivingSummaryReport: Decodable {
    let period: ReportPeriod
    let locationId: String?
    let summary: ReceivingSummaryData
    let bySupplier: [SupplierReceivingSummary]?
    let byProduct: [ProductReceivingSummary]?
}

struct ReceivingSummaryData: Decodable {
    let totalReceivings: Int
    let totalQuantity: Int
    let totalCost: String
    let averageCostPerUnit: String
}

struct SupplierReceivingSummary: Decodable, Identifiable {
    let supplierId: String?
    let supplierName: String
    let receivingCount: Int
    let totalQuantity: Int
    let totalCost: String
    
    var id: String { supplierId ?? supplierName }
}

struct ProductReceivingSummary: Decodable, Identifiable {
    let productId: String
    let productName: String
    let receivingCount: Int
    let totalQuantity: Int
    let totalCost: String
    let averageCost: String
    
    var id: String { productId }
}

// MARK: - API Response Wrappers

struct COGSReportResponse: Decodable {
    let success: Bool
    let data: COGSReport
}

struct ValuationReportResponse: Decodable {
    let success: Bool
    let data: ValuationReport
}

struct ProfitMarginReportResponse: Decodable {
    let success: Bool
    let data: ProfitMarginReport
}

struct ProfitLossReportResponse: Decodable {
    let success: Bool
    let data: ProfitLossReport
}

struct AdjustmentImpactReportResponse: Decodable {
    let success: Bool
    let data: AdjustmentImpactReport
}

struct ReceivingSummaryReportResponse: Decodable {
    let success: Bool
    let data: ReceivingSummaryReport
}
