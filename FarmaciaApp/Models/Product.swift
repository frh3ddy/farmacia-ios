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
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
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
