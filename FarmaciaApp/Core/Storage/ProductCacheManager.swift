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
        // Autosave off: we save explicitly after batch writes (avoids double writes)
        self.modelContext?.autosaveEnabled = false
    }
    
    // MARK: - Read Operations
    
    /// Load cached products for list display on cold start.
    /// Capped: the server page (50 items) replaces this immediately, so mapping
    /// thousands of rows on MainActor would be wasted work.
    func loadAll(limit: Int = 50) -> [Product] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<CachedProduct>(
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor))?.map { $0.toProduct() } ?? []
    }
    
    /// Find a product by exact SKU match (for barcode scanner).
    /// Indexed lookup on normalizedSku — no full-table scan, no in-memory filtering.
    /// NOTE: rows cached before normalizedSku existed have nil and are missed;
    /// the server exact-search (level 2) covers them, and warm-up repopulates.
    func findBySku(_ sku: String) -> Product? {
        guard let context = modelContext else { return nil }
        let lowered = sku.lowercased()
        var descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate<CachedProduct> { cached in
                cached.normalizedSku == lowered
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.toProduct()
    }
    
    /// Check if cache has any data
    var isEmpty: Bool {
        guard let context = modelContext else { return true }
        return (try? context.fetchCount(FetchDescriptor<CachedProduct>())) == 0
    }
    
    /// Total number of cached products (for warm-up progress display)
    var cachedCount: Int {
        guard let context = modelContext else { return 0 }
        return (try? context.fetchCount(FetchDescriptor<CachedProduct>())) ?? 0
    }
    
    // MARK: - Write Operations
    
    /// Save/update an array of products from an API response.
    /// Single batch fetch for existing rows (no N+1), then update or insert.
    func saveProducts(_ products: [Product]) {
        guard let context = modelContext, !products.isEmpty else { return }
        
        let ids = products.map { $0.id }
        let descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate<CachedProduct> { ids.contains($0.id) }
        )
        let existingById = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(descriptor)) ?? []).map { ($0.id, $0) }
        )
        
        for product in products {
            if let existing = existingById[product.id] {
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
