import Foundation
import FarmaciaKit

// MARK: - Adjustment Type
// The type itself lives in FarmaciaKit; the SF Symbol stays app-side.

extension AdjustmentType {
    var icon: String {
        switch self {
        case .damage: "exclamationmark.triangle"
        case .theft: "lock.slash"
        case .expired: "calendar.badge.exclamationmark"
        case .countCorrection: "number"
        case .openingCount: "checklist"
        case .found: "magnifyingglass"
        case .returnType: "arrow.uturn.backward"
        case .transferOut: "arrow.right.square"
        case .transferIn: "arrow.left.square"
        case .writeOff: "xmark.circle"
        case .other, .unknown: "ellipsis.circle"
        case .breakBulkOut: "shippingbox"
        case .breakBulkIn: "shippingbox.fill"
        case .autoSaleCover: "wand.and.stars"
        }
    }
}

// MARK: - Inventory Adjustment

struct InventoryAdjustment: Codable, Identifiable {
    let id: String
    let locationId: String
    let productId: String
    let type: AdjustmentType
    let quantity: Int
    let unitCost: String?
    let totalCost: String?
    let reason: String?
    let notes: String?
    let adjustedBy: String?
    let adjustedAt: Date
    let effectiveDate: Date?
    let squareSynced: Bool?
    let squareSyncedAt: Date?
    let squareSyncError: String?
    let createdBatchId: String?
    let product: Product?
    let location: Location?
    
    var unitCostDouble: Double? {
        unitCost.flatMap { Double($0) }
    }
    
    var totalCostDouble: Double? {
        totalCost.flatMap { Double($0) }
    }
    
    var quantityDisplay: String {
        if quantity > 0 {
            return "+\(quantity)"
        }
        return "\(quantity)"
    }
}

// MARK: - Adjustment Responses

struct AdjustmentResponse: Decodable {
    let success: Bool
    let message: String
    let data: AdjustmentData?
    
    struct AdjustmentData: Decodable {
        let adjustment: AdjustmentInfo
        let squareSync: SquareSyncResult?
        let inventoryImpact: InventoryImpact?
        let consumptions: [ConsumptionInfo]?
        
        struct AdjustmentInfo: Decodable {
            let id: String
            let type: String
            let quantity: Int
            let unitCost: String?
            let totalCost: String?
            let adjustedAt: Date
            let effectiveDate: Date?
            let reason: String?
            let notes: String?
        }
        
        struct InventoryImpact: Decodable {
            let previousTotal: Int
            let newTotal: Int
            let batchesConsumed: Int?
            let batchCreated: String?
        }
        
        struct ConsumptionInfo: Decodable {
            let inventoryId: String
            let quantity: Int
            let unitCost: String
        }
    }
}

struct AdjustmentListResponse: Decodable {
    let success: Bool
    let count: Int
    let data: [InventoryAdjustment]
}

struct RetrySquareSyncResponse: Decodable {
    let success: Bool
    let message: String
    let data: SquareSyncResult?
}
