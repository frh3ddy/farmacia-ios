import Foundation

// MARK: - Product

struct Product: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let sku: String?
    let barcode: String?
    let categoryId: String?
    let isActive: Bool
    let squareProductId: String?
    let squareVariationId: String?
    let squareProductName: String?
    let squareDescription: String?
    let squareImageUrl: String?
    let squareVariationName: String?
    let squareDataSyncedAt: Date?
    let category: Category?
    
    var displayName: String {
        squareProductName ?? name
    }
    
    var displayDescription: String? {
        squareDescription
    }
    
    static func == (lhs: Product, rhs: Product) -> Bool {
        lhs.id == rhs.id
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

struct Supplier: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let contactName: String?
    let email: String?
    let phone: String?
    let address: String?
    let isActive: Bool
    
    static func == (lhs: Supplier, rhs: Supplier) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Product List Response

struct ProductListResponse: Decodable {
    let products: [Product]
    let count: Int
}
