import Foundation
import SwiftData

// MARK: - ProductCacheManager
/// Manages SwiftData read/write for cached products.
/// All operations are synchronous on the caller's context (MainActor for UI reads).
/// NO business logic here — just CRUD on the cache.

@MainActor
final class ProductCacheManager {
    static let shared = ProductCacheManager()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    private init() {}
    
    /// Initialize with SwiftData container. Call once at app startup.
    func configure(container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
        self.modelContext?.autosaveEnabled = true
    }
    
    // MARK: - Read Operations
    
    /// Load all cached products (for list display on cold start)
    func loadAll() -> [Product] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<CachedProduct>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor))?.map { $0.toProduct() } ?? []
    }
    
    /// Find a product by exact SKU match (for barcode scanner)
    func findBySku(_ sku: String) -> Product? {
        guard let context = modelContext else { return nil }
        let lowered = sku.lowercased()
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate<CachedProduct> { cached in
                cached.sku != nil
            }
        )
        // SwiftData predicate doesn't support .lowercased() so we filter in Swift
        guard let results = try? context.fetch(descriptor) else { return nil }
        return results.first(where: { $0.sku?.lowercased() == lowered })?.toProduct()
    }
    
    /// Check if cache has any data
    var isEmpty: Bool {
        guard let context = modelContext else { return true }
        return (try? context.fetchCount(FetchDescriptor<CachedProduct>())) == 0
    }
    
    /// Check if cache was refreshed within the given interval
    func isFresh(within seconds: TimeInterval = 300) -> Bool {
        guard let context = modelContext else { return false }
        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == "products_last_sync" }
        )
        guard let meta = try? context.fetch(descriptor).first else { return false }
        return meta.updatedAt.timeIntervalSinceNow > -seconds
    }
    
    // MARK: - Write Operations
    
    /// Save/update an array of products from an API response
    func saveProducts(_ products: [Product]) {
        guard let context = modelContext else { return }
        
        for product in products {
            let productId = product.id
            let descriptor = FetchDescriptor<CachedProduct>(
                predicate: #Predicate<CachedProduct> { $0.id == productId }
            )
            
            if let existing = try? context.fetch(descriptor).first {
                existing.update(from: product)
            } else {
                context.insert(CachedProduct(from: product))
            }
        }
        
        try? context.save()
    }
    
    /// Save/update a single product (after detail view refresh or write operation)
    func saveProduct(_ product: Product) {
        guard let context = modelContext else { return }
        let productId = product.id
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate<CachedProduct> { $0.id == productId }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: product)
        } else {
            context.insert(CachedProduct(from: product))
        }
        
        try? context.save()
    }
    
    /// Mark cache as freshly synced
    func markFresh() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == "products_last_sync" }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            existing.updatedAt = Date()
        } else {
            context.insert(SyncMetadata(key: "products_last_sync", value: "true"))
        }
        
        try? context.save()
    }
    
    /// Clear all cached products (e.g., on location switch or logout)
    func clearAll() {
        guard let context = modelContext else { return }
        do {
            try context.delete(model: CachedProduct.self)
            try context.delete(model: SyncMetadata.self)
            try context.save()
        } catch {
            print("Failed to clear product cache: \(error)")
        }
    }
}
