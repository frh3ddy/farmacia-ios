import Foundation

// MARK: - Adjustment Type

enum AdjustmentType: String, Codable, CaseIterable {
    case damage = "DAMAGE"
    case theft = "THEFT"
    case expired = "EXPIRED"
    case countCorrection = "COUNT_CORRECTION"
    case found = "FOUND"
    case returnType = "RETURN"
    case transferOut = "TRANSFER_OUT"
    case transferIn = "TRANSFER_IN"
    case writeOff = "WRITE_OFF"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .damage: return "Damage"
        case .theft: return "Theft"
        case .expired: return "Expired"
        case .countCorrection: return "Count Correction"
        case .found: return "Found"
        case .returnType: return "Return"
        case .transferOut: return "Transfer Out"
        case .transferIn: return "Transfer In"
        case .writeOff: return "Write-off"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .damage: return "exclamationmark.triangle"
        case .theft: return "lock.slash"
        case .expired: return "calendar.badge.exclamationmark"
        case .countCorrection: return "number"
        case .found: return "magnifyingglass"
        case .returnType: return "arrow.uturn.backward"
        case .transferOut: return "arrow.right.square"
        case .transferIn: return "arrow.left.square"
        case .writeOff: return "xmark.circle"
        case .other: return "ellipsis.circle"
        }
    }
    
    var isPositive: Bool {
        switch self {
        case .found, .returnType, .transferIn, .countCorrection:
            return true
        default:
            return false
        }
    }
    
    var isNegative: Bool {
        switch self {
        case .damage, .theft, .expired, .transferOut, .writeOff:
            return true
        default:
            return false
        }
    }
    
    var isVariable: Bool {
        switch self {
        case .countCorrection, .other:
            return true
        default:
            return false
        }
    }
    
    var color: String {
        if isPositive {
            return "green"
        } else if isNegative {
            return "red"
        } else {
            return "orange"
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

struct AdjustmentSummaryResponse: Decodable {
    let summary: AdjustmentSummary
}

struct AdjustmentSummary: Decodable {
    let totalAdjustments: Int
    let totalLoss: String
    let totalGain: String
    let netImpact: String
    let byType: [AdjustmentTypeSummary]?
    let byProduct: [ProductAdjustmentSummary]?
}

struct AdjustmentTypeSummary: Decodable {
    let type: AdjustmentType
    let count: Int
    let totalQuantity: Int
    let totalCost: String
}

struct ProductAdjustmentSummary: Decodable {
    let productId: String
    let productName: String?
    let count: Int
    let totalQuantity: Int
    let totalCost: String
}

// MARK: - Adjustment Types Response

struct AdjustmentTypesResponse: Decodable {
    let types: [AdjustmentTypeInfo]
}

struct AdjustmentTypeInfo: Decodable {
    let value: String
    let label: String
    let isPositive: Bool
    let isNegative: Bool
    let isVariable: Bool
}
