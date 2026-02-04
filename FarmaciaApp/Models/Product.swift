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
    
    /// Formatted selling price in MXN
    var formattedPrice: String? {
        guard let price = sellingPrice else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: price))
    }
    
    /// Formatted average cost in MXN
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

// MARK: - Product List Response

struct ProductListResponse: Decodable {
    let data: [Product]
    let count: Int
}

// MARK: - Supplier List Response

struct SupplierListResponse: Decodable {
    let data: [Supplier]
    let count: Int
}
