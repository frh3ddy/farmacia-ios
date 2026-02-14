import Foundation

// MARK: - Product

struct Product: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let sku: String?
    let categoryId: String?
    let squareProductName: String?
    let squareDescription: String?
    let squareImageUrl: String?
    let squareVariationName: String?
    let squareDataSyncedAt: Date?
    let category: Category?
    let supplierCount: Int?
    let createdAt: Date?
    
    // Price and inventory fields (from new products endpoint)
    let sellingPrice: Double?
    let currency: String?
    let totalInventory: Int?
    let averageCost: Double?
    let hasSquareSync: Bool?
    
    var displayName: String {
        // Use Square product name, then variation name, then fallback to name
        let cleanSquareName = squareProductName?.trimmingCharacters(in: .whitespaces)
        let cleanVarName = squareVariationName?.trimmingCharacters(in: .whitespaces)
        
        if let sqName = cleanSquareName, !sqName.isEmpty, 
           !sqName.lowercased().contains("sin variaci"),
           !sqName.lowercased().contains("no variation") {
            return sqName
        }
        if let varName = cleanVarName, !varName.isEmpty,
           !varName.lowercased().contains("sin variaci"),
           !varName.lowercased().contains("no variation") {
            return varName
        }
        return name
    }
    
    var displayDescription: String? {
        squareDescription
    }
    
    /// Precio de venta formateado en MXN
    var formattedPrice: String? {
        guard let price = sellingPrice else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: price))
    }
    
    /// Costo promedio formateado en MXN
    var formattedCost: String? {
        guard let cost = averageCost else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: cost))
    }
    
    /// Profit margin percentage
    var profitMargin: Double? {
        guard let price = sellingPrice, let cost = averageCost, price > 0 else { return nil }
        return ((price - cost) / price) * 100
    }
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Create Product Request

struct CreateProductRequest: Encodable {
    let name: String
    let sku: String?
    let description: String?
    let sellingPrice: Double
    let costPrice: Double?
    let initialStock: Int?
    let locationId: String?
    let syncToSquare: Bool
}

// MARK: - Create Product Response

struct CreateProductResponse: Decodable {
    let product: Product
    let squareSynced: Bool
    let squareItemId: String?
    let squareVariationId: String?
    let inventoryCreated: Bool
}

// MARK: - Update Price Request

struct UpdatePriceRequest: Encodable {
    let sellingPrice: Double
    let locationId: String?
    let syncToSquare: Bool
    let applyToAllLocations: Bool?
}

// MARK: - Update Price Response

struct UpdatePriceResponse: Decodable {
    let product: Product
    let previousPrice: Double?
    let newPrice: Double
    let squareSynced: Bool
}

// MARK: - Category

struct Category: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let squareCategoryId: String?
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Supplier

struct Supplier: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let normalizedName: String?
    let initials: [String]?
    let contactInfo: String?
    let isActive: Bool?
    let createdAt: Date?
    let updatedAt: Date?
    
    static func == (lhs: Supplier, rhs: Supplier) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Product List Response (paginated)

struct ProductListResponse: Decodable {
    let data: [Product]
    let count: Int
    // Pagination metadata (present when backend paginates)
    let page: Int?
    let limit: Int?
    let totalCount: Int?
    let totalPages: Int?
    let hasMore: Bool?
}

// MARK: - Supplier List Response

struct SupplierListResponse: Decodable {
    let data: [Supplier]
    let count: Int
}

// MARK: - Product Supplier (from SupplierProduct table)

struct ProductSupplier: Decodable, Identifiable {
    let id: String
    let name: String
    let contactInfo: String?
    let isActive: Bool?
    let cost: String
    let isPreferred: Bool
    let notes: String?
    
    var costDouble: Double {
        Double(cost) ?? 0
    }
    
    var formattedCost: String {
        String(format: "$%.2f", costDouble)
    }
}

struct ProductSuppliersResponse: Decodable {
    let success: Bool
    let suppliers: [ProductSupplier]
}

// MARK: - Supplier Cost History (from SupplierCostHistory table)

struct CostHistoryEntry: Decodable, Identifiable {
    let id: String
    let cost: String
    let effectiveAt: Date
    let createdAt: Date
    let source: String
    let isCurrent: Bool
    
    var costDouble: Double {
        Double(cost) ?? 0
    }
    
    var formattedCost: String {
        String(format: "$%.2f", costDouble)
    }
    
    var sourceLabel: String {
        switch source {
        case "MIGRATION": return "Migración"
        case "INVENTORY_UPDATE": return "Actualización de Inventario"
        case "MANUAL": return "Manual"
        default: return source
        }
    }
}

struct SupplierCostHistoryGroup: Decodable, Identifiable {
    let supplierId: String
    let supplierName: String
    let costHistory: [CostHistoryEntry]
    
    var id: String { supplierId }
    
    var currentCost: CostHistoryEntry? {
        costHistory.first { $0.isCurrent }
    }
    
    var latestCost: CostHistoryEntry? {
        costHistory.first // Already sorted by effectiveAt desc from backend
    }
    
    var costTrend: (change: Double, percent: Double)? {
        guard costHistory.count >= 2,
              let latest = costHistory.first,
              let previous = costHistory.dropFirst().first else { return nil }
        let change = latest.costDouble - previous.costDouble
        let percent = previous.costDouble > 0 ? (change / previous.costDouble) * 100 : 0
        return (change, percent)
    }
}

struct ProductCostHistoryResponse: Decodable {
    let success: Bool
    let suppliers: [SupplierCostHistoryGroup]
}

// MARK: - Supplier Catalog Item (for Purchase Orders / Shopping List)

struct SupplierCatalogItem: Decodable, Identifiable {
    let productId: String
    let productName: String
    let sku: String?
    let imageUrl: String?
    let lastCost: String
    let isPreferred: Bool
    let notes: String?
    let currentStock: Int
    
    var id: String { productId }
    
    var lastCostDouble: Double {
        Double(lastCost) ?? 0
    }
    
    var formattedCost: String {
        String(format: "$%.2f", lastCostDouble)
    }
    
    var isLowStock: Bool {
        currentStock > 0 && currentStock < 10
    }
    
    var isOutOfStock: Bool {
        currentStock <= 0
    }
}

struct SupplierCatalogResponse: Decodable {
    let success: Bool
    let products: [SupplierCatalogItem]
}
