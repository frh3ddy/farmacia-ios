import Foundation

// MARK: - Inventory Batch
// Note: Some fields are optional to handle minimal responses in receiving endpoints

struct InventoryBatch: Codable, Identifiable {
    let id: String
    let locationId: String?      // Optional for minimal responses
    let productId: String?       // Optional for minimal responses
    let quantity: Int
    let unitCost: String         // Decimal as string
    let receivedAt: Date
    let source: InventorySource? // Optional for minimal responses
    let costSource: CostSource?  // Optional for minimal responses
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
        case .purchase: return "Compra"
        case .adjustment: return "Ajuste"
        case .migration: return "Migración"
        case .transfer: return "Transferencia"
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
        case .invoice: return "Factura"
        case .estimated: return "Estimado"
        case .migration: return "Migración"
        case .manual: return "Entrada Manual"
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
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: receivedAt)
    }
    
    var formattedUnitCost: String {
        let cost = unitCostDouble
        return String(format: "$%.2f", cost)
    }
    
    var formattedTotalCost: String {
        let cost = totalCostDouble
        return String(format: "$%.2f", cost)
    }
}

// MARK: - Receiving Create Response
// Backend returns simplified structure for create (different from get)

struct ReceivingCreateResponse: Decodable {
    let success: Bool
    let message: String
    let data: ReceivingCreateData
}

struct ReceivingCreateData: Decodable {
    let receiving: CreatedReceiving
    let inventoryBatch: CreatedBatch
    let squareSync: SquareSyncResult?
    let inventoryTotal: Int
}

struct CreatedReceiving: Decodable {
    let id: String
    let quantity: Int
    let unitCost: String
    let totalCost: String
    let invoiceNumber: String?
    let batchNumber: String?
    let receivedAt: Date
}

struct CreatedBatch: Decodable {
    let id: String
    let quantity: Int
    let unitCost: String
    let receivedAt: Date
}

// MARK: - Receiving Get Response

struct ReceivingGetResponse: Decodable {
    let success: Bool
    let data: InventoryReceiving
}

// MARK: - Receiving List Response

struct ReceivingListResponse: Decodable {
    let success: Bool
    let count: Int
    let data: [InventoryReceiving]
}

// MARK: - Receiving Summary Response

struct ReceivingSummaryResponse: Decodable {
    let success: Bool
    let data: ReceivingSummary
}

struct ReceivingSummary: Decodable {
    let totalReceivings: Int
    let totalQuantity: Int
    let totalCost: String
    let bySupplier: [SupplierSummary]?
    let byProduct: [ProductSummary]?
    
    var formattedTotalCost: String {
        let cost = Double(totalCost) ?? 0
        return String(format: "$%.2f", cost)
    }
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
    let synced: Bool?  // Backend uses 'synced' not 'success'
    let success: Bool? // Fallback
    let syncedAt: Date?
    let error: String?
    
    var isSuccess: Bool {
        synced ?? success ?? false
    }
}

// MARK: - Product List Response

struct ProductsResponse: Decodable {
    let success: Bool
    let data: [Product]
    let count: Int
}

// MARK: - Supplier List Response

struct SuppliersResponse: Decodable {
    let success: Bool
    let suppliers: [SupplierInfo]
}

struct SupplierInfo: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let initials: [String]?
    let contactInfo: String?
    let isActive: Bool
    let createdAt: String?
    let updatedAt: String?
    
    static func == (lhs: SupplierInfo, rhs: SupplierInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Supplier Search Response

struct SupplierSearchResponse: Decodable {
    let success: Bool
    let suppliers: [SupplierInfo]
}
