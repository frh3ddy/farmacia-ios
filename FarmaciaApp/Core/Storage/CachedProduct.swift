import Foundation
import SwiftData
import FarmaciaKit

// MARK: - CachedProduct (SwiftData persistence for offline/instant loading)

@Model
final class CachedProduct {
    @Attribute(.unique) var id: String
    var name: String
    var sku: String?
    /// Lowercased SKU for indexed barcode lookup (SwiftData predicates don't support lowercased())
    var normalizedSku: String?
    /// The barcode (digits, so no normalizing) for the scanner's lookup.
    var gtin: String?
    var categoryId: String?
    var categoryName: String?
    
    // Square data
    var squareProductName: String?
    var squareDescription: String?
    var squareImageUrl: String?
    var squareVariationName: String?
    var squareDataSyncedAt: Date?
    
    // Pricing (denormalized for fast list display). No cost: it's role-dependent
    // and shouldn't sit on the device; cached rows show it as unknown, and screens
    // that need it (detail) refresh from the server. See ProductCacheScope.
    var sellingPrice: Double?
    var currency: String?
    
    // Inventory (denormalized)
    var totalInventory: Int
    var hasSquareSync: Bool
    var tracksInventory: Bool?
    /// This store's StockAlert, encoded (StockAlert.cacheData); nil on rows cached
    /// before stock alerts, which fall back to the fixed cutoffs.
    var stockAlertData: Data?
    
    // Supplier count
    var supplierCount: Int?
    
    // Sync metadata
    var lastFetchedAt: Date
    var serverCreatedAt: Date?
    
    init(from product: Product) {
        self.id = product.id
        self.name = product.name
        self.sku = product.sku
        self.normalizedSku = product.sku?.lowercased()
        self.gtin = product.gtin
        self.categoryId = product.categoryId
        self.categoryName = product.category?.name
        self.squareProductName = product.squareProductName
        self.squareDescription = product.squareDescription
        self.squareImageUrl = product.squareImageUrl
        self.squareVariationName = product.squareVariationName
        self.squareDataSyncedAt = product.squareDataSyncedAt
        self.sellingPrice = product.sellingPrice
        self.currency = product.currency
        self.totalInventory = product.totalInventory ?? 0
        self.hasSquareSync = product.hasSquareSync ?? false
        self.tracksInventory = product.tracksInventory
        self.stockAlertData = product.stockAlert?.cacheData
        self.supplierCount = product.supplierCount
        self.lastFetchedAt = Date()
        self.serverCreatedAt = product.createdAt
    }
    
    /// Update existing cached product with fresh data from server
    func update(from product: Product) {
        name = product.name
        sku = product.sku
        normalizedSku = product.sku?.lowercased()
        gtin = product.gtin
        categoryId = product.categoryId
        categoryName = product.category?.name
        squareProductName = product.squareProductName
        squareDescription = product.squareDescription
        squareImageUrl = product.squareImageUrl
        squareVariationName = product.squareVariationName
        squareDataSyncedAt = product.squareDataSyncedAt
        sellingPrice = product.sellingPrice
        currency = product.currency
        totalInventory = product.totalInventory ?? 0
        hasSquareSync = product.hasSquareSync ?? false
        tracksInventory = product.tracksInventory
        stockAlertData = product.stockAlert?.cacheData
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
            averageCost: nil,
            hasSquareSync: hasSquareSync,
            tracksInventory: tracksInventory,
            gtin: gtin,
            stockAlert: StockAlert(cacheData: stockAlertData)
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
