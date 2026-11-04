import Foundation
import FarmaciaKit
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
    
    // MARK: - Scope

    private static let scopeKey = "products_scope"

    /// Call on every login and store switch, before anything reads the cache: rows
    /// saved for another store (e.g. before an app restart) are dropped; a role
    /// change at the same store keeps them (no cost is cached). See ProductCacheScope.
    func prepare(for scope: ProductCacheScope) {
        guard let context = modelContext else { return }
        let key = Self.scopeKey
        let descriptor = FetchDescriptor<SyncMetadata>(predicate: #Predicate<SyncMetadata> { $0.key == key })
        let stored = try? context.fetch(descriptor).first
        guard scope.needsClear(storedKey: stored?.value) else { return }
        clearAll() // also drops the stored scope
        context.insert(SyncMetadata(key: Self.scopeKey, value: scope.key))
        try? context.save()
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
    
    /// Products with this exact SKU (for barcode scanner), up to `limit`: enough to
    /// tell one match from several (BarcodeLookup.cacheDecision).
    /// Indexed lookup on normalizedSku — no full-table scan, no in-memory filtering.
    /// NOTE: rows cached before normalizedSku existed have nil and are missed;
    /// the server exact-search (level 2) covers them, and warm-up repopulates.
    /// Products with this barcode, up to `limit` (like findBySku).
    func findByGtin(_ gtin: String, limit: Int = 2) -> [Product] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate<CachedProduct> { cached in
                cached.gtin == gtin
            }
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toProduct() }
    }

    func findBySku(_ sku: String, limit: Int = 2) -> [Product] {
        guard let context = modelContext else { return [] }
        let lowered = sku.lowercased()
        var descriptor = FetchDescriptor<CachedProduct>(
            predicate: #Predicate<CachedProduct> { cached in
                cached.normalizedSku == lowered
            }
        )
        descriptor.fetchLimit = limit
        return ((try? context.fetch(descriptor)) ?? []).map { $0.toProduct() }
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
    
    // MARK: - Delta Sync

    private static let cursorKey = "products_sync_cursor"

    /// The cursor the last finished sync saved for this store; nil means walk everything.
    /// A store switch clears it with the rows (prepare(for:) → clearAll).
    func syncCursor(for scope: ProductCacheScope) -> String? {
        guard storedValue(Self.scopeKey) == scope.key else { return nil }
        return storedValue(Self.cursorKey)
    }

    /// Writes a finished sync and its cursor in one save, so a cursor never points past
    /// rows the cache doesn't hold. Dropped if the cache now belongs to another store.
    func applySync(_ result: ProductSyncResult<Product>, for scope: ProductCacheScope) {
        guard let context = modelContext, storedValue(Self.scopeKey) == scope.key else { return }

        let cachedIds = Set(((try? context.fetch(FetchDescriptor<CachedProduct>())) ?? []).map(\.id))
        let doomed = result.idsToDelete(cached: cachedIds)
        if !doomed.isEmpty {
            try? context.delete(model: CachedProduct.self, where: #Predicate<CachedProduct> { doomed.contains($0.id) })
        }

        let ids = result.upserts.map(\.id)
        let existing = (try? context.fetch(FetchDescriptor<CachedProduct>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for product in result.upserts {
            if let row = existingById[product.id] {
                row.update(from: product)
            } else {
                context.insert(CachedProduct(from: product))
            }
        }

        let key = Self.cursorKey
        if let stored = try? context.fetch(FetchDescriptor<SyncMetadata>(predicate: #Predicate { $0.key == key })).first {
            stored.value = result.cursor
            stored.updatedAt = Date()
        } else {
            context.insert(SyncMetadata(key: key, value: result.cursor))
        }
        try? context.save()
    }

    private func storedValue(_ key: String) -> String? {
        let descriptor = FetchDescriptor<SyncMetadata>(predicate: #Predicate<SyncMetadata> { $0.key == key })
        return (try? modelContext?.fetch(descriptor).first)?.value
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
