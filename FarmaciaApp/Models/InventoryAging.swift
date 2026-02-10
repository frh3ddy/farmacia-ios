import Foundation
import SwiftUI

// MARK: - Inventory Aging Models
// Maps to backend: /inventory/aging/* endpoints
// Service: InventoryAgingService with bucket classification, risk levels, and actionable signals

// MARK: - Aging Bucket (from backend bucket config)

struct AgingBucketInfo: Decodable {
    let label: String
    let min: Int
    let max: Int?  // null = Infinity (90+ bucket)
}

// MARK: - Bucket Summary (aggregated data per bucket)

struct AgingBucketSummaryItem: Decodable, Identifiable {
    let bucket: AgingBucketInfo
    let cashValue: Double
    let unitCount: Int
    let percentageOfTotal: Double
    
    var id: String { bucket.label }
    
    var formattedCashValue: String {
        String(format: "$%.2f", cashValue)
    }
}

// MARK: - Aging Summary Response (GET /inventory/aging/summary)

struct AgingOverviewResponse: Decodable {
    let buckets: [AgingBucketSummaryItem]
    let totalCashTiedUp: Double
    let totalUnits: Int
    
    var formattedTotalCash: String {
        String(format: "$%.2f", totalCashTiedUp)
    }
}

// MARK: - Product Aging Analysis (GET /inventory/aging/products)

enum InventoryRiskLevel: String, Decodable, CaseIterable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    /// Sort priority (lower = more severe = appears first)
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

struct ProductAgingAnalysis: Decodable, Identifiable {
    let productId: String
    let productName: String
    let categoryName: String?
    let totalCashTiedUp: Double
    let totalUnits: Int
    let oldestBatchAge: Int
    let bucketDistribution: [AgingBucketSummaryItem]
    let riskLevel: InventoryRiskLevel
    
    var id: String { productId }
    
    var formattedCashTiedUp: String {
        String(format: "$%.2f", totalCashTiedUp)
    }
}

struct ProductAgingResponse: Decodable {
    let products: [ProductAgingAnalysis]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Location Aging Analysis (GET /inventory/aging/location)

struct LocationAgingAnalysis: Decodable, Identifiable {
    let locationId: String
    let locationName: String
    let totalCashTiedUp: Double
    let totalUnits: Int
    let bucketDistribution: [AgingBucketSummaryItem]
    let atRiskProducts: Int
    
    var id: String { locationId }
    
    var formattedCashTiedUp: String {
        String(format: "$%.2f", totalCashTiedUp)
    }
}

struct LocationAgingResponse: Decodable {
    let locations: [LocationAgingAnalysis]
}

// MARK: - Category Aging Analysis (GET /inventory/aging/category)

struct CategoryAgingAnalysis: Decodable, Identifiable {
    let categoryId: String
    let categoryName: String
    let totalCashTiedUp: Double
    let totalUnits: Int
    let bucketDistribution: [AgingBucketSummaryItem]
    let averageAge: Double
    
    var id: String { categoryId }
    
    var formattedCashTiedUp: String {
        String(format: "$%.2f", totalCashTiedUp)
    }
}

struct CategoryAgingResponse: Decodable {
    let categories: [CategoryAgingAnalysis]
}

// MARK: - Actionable Signals (GET /inventory/aging/signals)

enum SignalType: String, Decodable {
    case atRisk = "AT_RISK"
    case slowMovingExpensive = "SLOW_MOVING_EXPENSIVE"
    case overstockedCategory = "OVERSTOCKED_CATEGORY"
    
    var displayName: String {
        switch self {
        case .atRisk: return "At Risk"
        case .slowMovingExpensive: return "Slow Moving"
        case .overstockedCategory: return "Overstocked"
        }
    }
    
    var icon: String {
        switch self {
        case .atRisk: return "exclamationmark.triangle.fill"
        case .slowMovingExpensive: return "tortoise.fill"
        case .overstockedCategory: return "archivebox.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .atRisk: return .red
        case .slowMovingExpensive: return .orange
        case .overstockedCategory: return .purple
        }
    }
}

enum SignalEntityType: String, Decodable {
    case product = "PRODUCT"
    case location = "LOCATION"
    case category = "CATEGORY"
}

struct ActionableSignal: Decodable, Identifiable {
    let type: SignalType
    let severity: InventoryRiskLevel
    let entityType: SignalEntityType
    let entityId: String
    let entityName: String
    let message: String
    let recommendedActions: [String]
    let cashAtRisk: Double?
    
    var id: String { "\(type.rawValue)-\(entityId)" }
    
    var formattedCashAtRisk: String? {
        guard let cash = cashAtRisk else { return nil }
        return String(format: "$%.2f", cash)
    }
}

struct ActionableSignalsResponse: Decodable {
    let signals: [ActionableSignal]
    let total: Int
}

// MARK: - Expiring Products Models
// Maps to: GET /inventory/aging/expiring

struct ExpiringBatchInfo: Decodable, Identifiable {
    let batchId: String
    let receivingId: String
    let quantity: Int
    let unitCost: Double
    let cashValue: Double
    let expiryDate: Date
    let daysUntilExpiry: Int
    let isExpired: Bool
    let batchNumber: String?
    let supplierName: String?
    let receivedAt: Date
    
    var id: String { batchId }
    
    var formattedCashValue: String {
        String(format: "$%.2f", cashValue)
    }
    
    var formattedUnitCost: String {
        String(format: "$%.2f", unitCost)
    }
    
    var expiryLabel: String {
        if isExpired {
            return "Expired \(abs(daysUntilExpiry))d ago"
        } else if daysUntilExpiry <= 30 {
            return "Expires in \(daysUntilExpiry)d"
        } else {
            return expiryDate.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

struct ExpiringProduct: Decodable, Identifiable {
    let productId: String
    let productName: String
    let sku: String?
    let totalUnits: Int
    let totalCashAtRisk: Double
    let batchCount: Int
    let expiredCount: Int
    let soonestExpiryDate: Date
    let soonestDaysUntilExpiry: Int
    let severity: String  // "LOW", "MEDIUM", "HIGH", "CRITICAL"
    let batches: [ExpiringBatchInfo]
    
    var id: String { productId }
    
    var formattedCashAtRisk: String {
        String(format: "$%.2f", totalCashAtRisk)
    }
    
    var severityColor: Color {
        switch severity {
        case "CRITICAL": return .red
        case "HIGH": return .orange
        case "MEDIUM": return .yellow
        case "LOW": return .green
        default: return .secondary
        }
    }
    
    var severityIcon: String {
        switch severity {
        case "CRITICAL": return "exclamationmark.triangle.fill"
        case "HIGH": return "exclamationmark.circle.fill"
        case "MEDIUM": return "clock.badge.exclamationmark"
        default: return "clock"
        }
    }
}

struct ExpiringProductsSummary: Decodable {
    let totalProducts: Int
    let totalExpiredBatches: Int
    let totalCashAtRisk: Double
    let criticalCount: Int
    let highCount: Int
}

struct ExpiringProductsResponse: Decodable {
    let products: [ExpiringProduct]
    let total: Int
    let summary: ExpiringProductsSummary
}

// MARK: - Batch Detail Models
// Maps to: GET /inventory/reports/batch/:batchId

struct BatchConsumptionSale: Decodable {
    let saleId: String
    let squareId: String
    let saleDate: Date
    let itemQuantity: Int
    let itemPrice: String
}

struct BatchConsumptionAdjustment: Decodable {
    let adjustmentId: String
    let type: String
    let reason: String?
    let adjustedAt: Date
}

struct BatchConsumption: Decodable, Identifiable {
    let id: String
    let quantity: Int
    let unitCost: String
    let totalCost: String
    let consumedAt: Date
    let type: String  // "SALE", "ADJUSTMENT", "UNKNOWN"
    let sale: BatchConsumptionSale?
    let adjustment: BatchConsumptionAdjustment?
    
    var typeLabel: String {
        switch type {
        case "SALE": return "Sale"
        case "ADJUSTMENT": return adjustment?.type ?? "Adjustment"
        default: return "Unknown"
        }
    }
    
    var typeIcon: String {
        switch type {
        case "SALE": return "cart"
        case "ADJUSTMENT": return "arrow.triangle.2.circlepath"
        default: return "questionmark.circle"
        }
    }
    
    var typeColor: Color {
        switch type {
        case "SALE": return .blue
        case "ADJUSTMENT": return .orange
        default: return .secondary
        }
    }
    
    var formattedTotalCost: String {
        if let cost = Double(totalCost) {
            return String(format: "$%.2f", cost)
        }
        return "$\(totalCost)"
    }
}

struct BatchReceivingDetail: Decodable {
    let id: String
    let batchNumber: String?
    let expiryDate: Date?
    let manufacturingDate: Date?
    let invoiceNumber: String?
    let supplierId: String?
    let supplierName: String?
    let receivedBy: String?
    let notes: String?
    let receivedAt: Date
}

struct BatchAdjustmentDetail: Decodable {
    let id: String
    let type: String
    let reason: String?
    let notes: String?
    let adjustedAt: Date
    let adjustedBy: String?
}

struct BatchDetail: Decodable {
    let batchId: String
    let productId: String
    let productName: String
    let productSku: String?
    let locationId: String
    let locationName: String
    let quantity: Int
    let unitCost: String
    let currentValue: String
    let receivedAt: Date
    let ageDays: Int
    let source: String?
    
    let originalQuantity: Int
    let totalConsumed: Int
    let remainingPercent: String
    
    let receiving: BatchReceivingDetail?
    let adjustment: BatchAdjustmentDetail?
    let consumptions: [BatchConsumption]
    let consumptionCount: Int
    
    var formattedUnitCost: String {
        if let cost = Double(unitCost) {
            return String(format: "$%.2f", cost)
        }
        return "$\(unitCost)"
    }
    
    var formattedCurrentValue: String {
        if let val = Double(currentValue) {
            return String(format: "$%.2f", val)
        }
        return "$\(currentValue)"
    }
    
    var sourceLabel: String {
        switch source {
        case "PURCHASE": return "Purchase"
        case "OPENING_BALANCE": return "Opening Balance"
        case "ADJUSTMENT": return "Adjustment"
        default: return source ?? "Unknown"
        }
    }
}

struct BatchDetailResponse: Decodable {
    let success: Bool
    let data: BatchDetail
}
