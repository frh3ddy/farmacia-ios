import Foundation
import SwiftData

// MARK: - CachedProduct (SwiftData persistence for offline/instant loading)

@Model
final class CachedProduct {
    @Attribute(.unique) var id: String
    var name: String
    var sku: String?
    var categoryId: String?
    var categoryName: String?
    
    // Square data
    var squareProductName: String?
    var squareDescription: String?
    var squareImageUrl: String?
    var squareVariationName: String?
    var squareDataSyncedAt: Date?
    
    // Pricing (denormalized for fast list display)
    var sellingPrice: Double?
    var currency: String?
    var averageCost: Double?
    
    // Inventory (denormalized)
    var totalInventory: Int
    var hasSquareSync: Bool
    
    // Supplier count
    var supplierCount: Int?
    
    // Sync metadata
    var lastFetchedAt: Date
    var serverCreatedAt: Date?
    
    init(from product: Product) {
        self.id = product.id
        self.name = product.name
        self.sku = product.sku
        self.categoryId = product.categoryId
        self.categoryName = product.category?.name
        self.squareProductName = product.squareProductName
        self.squareDescription = product.squareDescription
        self.squareImageUrl = product.squareImageUrl
        self.squareVariationName = product.squareVariationName
        self.squareDataSyncedAt = product.squareDataSyncedAt
        self.sellingPrice = product.sellingPrice
        self.currency = product.currency
        self.averageCost = product.averageCost
        self.totalInventory = product.totalInventory ?? 0
        self.hasSquareSync = product.hasSquareSync ?? false
        self.supplierCount = product.supplierCount
        self.lastFetchedAt = Date()
        self.serverCreatedAt = product.createdAt
    }
    
    /// Update existing cached product with fresh data from server
    func update(from product: Product) {
        name = product.name
        sku = product.sku
        categoryId = product.categoryId
        categoryName = product.category?.name
        squareProductName = product.squareProductName
        squareDescription = product.squareDescription
        squareImageUrl = product.squareImageUrl
        squareVariationName = product.squareVariationName
        squareDataSyncedAt = product.squareDataSyncedAt
        sellingPrice = product.sellingPrice
        currency = product.currency
        averageCost = product.averageCost
        totalInventory = product.totalInventory ?? 0
        hasSquareSync = product.hasSquareSync ?? false
        supplierCount = product.supplierCount
        lastFetchedAt = Date()
        serverCreatedAt = product.createdAt
    }
    
    /// Convert back to the existing Product struct for UI compatibility
    func toProduct() -> Product {
        Product(
            id: id,
            name: name,
            sku: sku,
            categoryId: categoryId,
            squareProductName: squareProductName,
            squareDescription: squareDescription,
            squareImageUrl: squareImageUrl,
            squareVariationName: squareVariationName,
            squareDataSyncedAt: squareDataSyncedAt,
            category: categoryName.map {
                Category(id: categoryId ?? "", name: $0, squareCategoryId: nil)
            },
            supplierCount: supplierCount,
            createdAt: serverCreatedAt,
            sellingPrice: sellingPrice,
            currency: currency,
            totalInventory: totalInventory,
            averageCost: averageCost,
            hasSquareSync: hasSquareSync
        )
    }
}

// MARK: - SyncMetadata (tracks when cache was last refreshed)

@Model
final class SyncMetadata {
    @Attribute(.unique) var key: String
    var value: String
    var updatedAt: Date
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
        self.updatedAt = Date()
    }
}
