import Foundation

// MARK: - Inventory Batch

struct InventoryBatch: Codable, Identifiable {
    let id: String
    let locationId: String
    let productId: String
    let quantity: Int
    let unitCost: String // Decimal as string
    let receivedAt: Date
    let source: InventorySource
    let costSource: CostSource
    let migrationId: String?
    let product: Product?
    let location: Location?
    
    var unitCostDouble: Double {
        Double(unitCost) ?? 0
    }
}

// MARK: - Inventory Source

enum InventorySource: String, Codable {
    case purchase = "PURCHASE"
    case adjustment = "ADJUSTMENT"
    case migration = "MIGRATION"
    case transfer = "TRANSFER"
    
    var displayName: String {
        switch self {
        case .purchase: return "Purchase"
        case .adjustment: return "Adjustment"
        case .migration: return "Migration"
        case .transfer: return "Transfer"
        }
    }
}

// MARK: - Cost Source

enum CostSource: String, Codable {
    case invoice = "INVOICE"
    case estimated = "ESTIMATED"
    case migration = "MIGRATION"
    case manual = "MANUAL"
    
    var displayName: String {
        switch self {
        case .invoice: return "Invoice"
        case .estimated: return "Estimated"
        case .migration: return "Migration"
        case .manual: return "Manual Entry"
        }
    }
}

// MARK: - Inventory Receiving

struct InventoryReceiving: Codable, Identifiable {
    let id: String
    let locationId: String
    let productId: String
    let supplierId: String?
    let quantity: Int
    let unitCost: String
    let totalCost: String
    let invoiceNumber: String?
    let purchaseOrderId: String?
    let batchNumber: String?
    let expiryDate: Date?
    let manufacturingDate: Date?
    let notes: String?
    let receivedBy: String?
    let receivedAt: Date
    let squareSynced: Bool?
    let squareSyncedAt: Date?
    let squareSyncError: String?
    let inventoryBatchId: String?
    let product: Product?
    let supplier: Supplier?
    let inventoryBatch: InventoryBatch?
    
    var unitCostDouble: Double {
        Double(unitCost) ?? 0
    }
    
    var totalCostDouble: Double {
        Double(totalCost) ?? 0
    }
}

// MARK: - Receiving Response

struct ReceivingResponse: Decodable {
    let receiving: InventoryReceiving
    let message: String
    let squareSync: SquareSyncResult?
}

struct ReceivingListResponse: Decodable {
    let receivings: [InventoryReceiving]
    let count: Int
}

struct ReceivingSummaryResponse: Decodable {
    let summary: ReceivingSummary
}

struct ReceivingSummary: Decodable {
    let totalReceivings: Int
    let totalQuantity: Int
    let totalCost: String
    let bySupplier: [SupplierSummary]?
    let byProduct: [ProductSummary]?
}

struct SupplierSummary: Decodable {
    let supplierId: String?
    let supplierName: String?
    let count: Int
    let totalQuantity: Int
    let totalCost: String
}

struct ProductSummary: Decodable {
    let productId: String
    let productName: String?
    let count: Int
    let totalQuantity: Int
    let totalCost: String
}

// MARK: - Square Sync Result

struct SquareSyncResult: Decodable {
    let success: Bool
    let syncedAt: Date?
    let error: String?
}
