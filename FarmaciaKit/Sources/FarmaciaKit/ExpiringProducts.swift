import Foundation

// MARK: - Expiring Products Models
// Maps to: GET /inventory/aging/expiring
// A cashier's body has no unitCost, cashValue or totalCashAtRisk (farmacia-ops
// `expiringWithoutCosts`), so those are optional.

public struct ExpiringBatchInfo: Decodable, Identifiable, Sendable {
    public let batchId: String
    // receivingId isn't read: a lot set by a Conteo inicial has none (null), and decoding it broke the list.
    public let quantity: Int
    public let unitCost: Double?
    public let cashValue: Double?
    public let expiryDate: Date
    public let daysUntilExpiry: Int
    public let isExpired: Bool
    public let batchNumber: String?
    public let supplierName: String?
    public let receivedAt: Date

    public var id: String { batchId }

    public var formattedCashValue: String? {
        cashValue.map { ReportFormat.currency($0) }
    }

    public var formattedUnitCost: String? {
        unitCost.map { ReportFormat.currency($0) }
    }

    public var expiryLabel: String {
        Expiry.label(daysUntil: daysUntilExpiry, isExpired: isExpired, expiry: expiryDate)
    }
}

public struct ExpiringProduct: Decodable, Identifiable, Sendable {
    public let productId: String
    public let productName: String
    public let sku: String?
    public let totalUnits: Int
    public let totalCashAtRisk: Double?
    public let batchCount: Int
    public let expiredCount: Int
    public let soonestExpiryDate: Date
    public let soonestDaysUntilExpiry: Int
    public let severity: String  // "LOW", "MEDIUM", "HIGH", "CRITICAL"
    public let batches: [ExpiringBatchInfo]

    public var id: String { productId }

    public var formattedCashAtRisk: String? {
        totalCashAtRisk.map { ReportFormat.currency($0) }
    }

    public var severityIcon: String {
        switch severity {
        case "CRITICAL": return "exclamationmark.triangle.fill"
        case "HIGH": return "exclamationmark.circle.fill"
        case "MEDIUM": return "clock.badge.exclamationmark"
        default: return "clock"
        }
    }
}

public struct ExpiringProductsSummary: Decodable, Sendable {
    public let totalProducts: Int
    public let totalExpiredBatches: Int
    public let totalCashAtRisk: Double?
    public let criticalCount: Int
    public let highCount: Int
}

public struct ExpiringProductsResponse: Decodable, Sendable {
    public let products: [ExpiringProduct]
    public let total: Int
    public let summary: ExpiringProductsSummary
}
