import Foundation

// MARK: - Products View Model (paginated, infinite scroll)

// MARK: - Pre-computed filter counts (avoids O(n) passes per SwiftUI render)
struct ProductCounts: Equatable {
    var total = 0
    var outOfStock = 0
    var lowStock = 0
    var inStock = 0
    var lowMargin = 0
    var synced = 0
    var local = 0
}

@MainActor
class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var filteredProducts: [Product] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Pre-computed counts — recalculated once when products array changes
    @Published var counts = ProductCounts()
    
    // Background catalog warm-up state (for non-blocking progress indicator)
    @Published var isWarmingCache = false
    @Published var warmUpProgress: Int = 0
    
    // Pagination state
    private(set) var currentPage = 1
    private(set) var hasMore = true
    private(set) var totalCount = 0
    private let pageSize = 50
    
    // Search state (server-side)
    private var currentSearchQuery: String?
    
    // Filter/sort inputs — recompute filteredProducts only when these change
    private var activeFilter: ProductFilter = .all
    private var activeSort: ProductSortOption = .name
    private var atRiskIds: Set<String> = []
    private var expiringIds: Set<String> = []
    
    // Background warm-up task (cancelled on refresh/search)
    private var warmUpTask: Task<Void, Never>?
    
    private let apiClient = APIClient.shared
    private let cache = ProductCacheManager.shared
    
    // MARK: - Filter / Sort (recomputed only on input change, NOT per render)
    
    func setFilter(_ filter: ProductFilter, atRiskIds: Set<String>, expiringIds: Set<String>) {
        activeFilter = filter
        self.atRiskIds = atRiskIds
        self.expiringIds = expiringIds
        recomputeFilteredProducts()
    }
    
    func setSort(_ sort: ProductSortOption) {
        activeSort = sort
        recomputeFilteredProducts()
    }
    
    private func recomputeFilteredProducts() {
        var result = products
        
        switch activeFilter {
        case .all:
            break
        case .lowStock:
            result = result.filter { ($0.totalInventory ?? 0) > 0 && ($0.totalInventory ?? 0) < 10 }
        case .outOfStock:
            result = result.filter { ($0.totalInventory ?? 0) == 0 }
        case .inStock:
            result = result.filter { ($0.totalInventory ?? 0) >= 10 }
        case .atRisk:
            let ids = atRiskIds
            result = result.filter { ids.contains($0.id) }
        case .expiringSoon:
            let ids = expiringIds
            result = result.filter { ids.contains($0.id) }
        case .lowMargin:
            result = result.filter { ($0.profitMargin ?? 100) < 10 }
        }
        
        switch activeSort {
        case .name:
            result.sort { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        case .stockAsc:
            result.sort { ($0.totalInventory ?? 0) < ($1.totalInventory ?? 0) }
        case .stockDesc:
            result.sort { ($0.totalInventory ?? 0) > ($1.totalInventory ?? 0) }
        case .margin:
            result.sort { ($0.profitMargin ?? 0) > ($1.profitMargin ?? 0) }
        case .priceAsc:
            result.sort { ($0.sellingPrice ?? 0) < ($1.sellingPrice ?? 0) }
        case .priceDesc:
            result.sort { ($0.sellingPrice ?? 0) > ($1.sellingPrice ?? 0) }
        }
        
        filteredProducts = result
    }
    
    /// Load first page: cache first → spinner → API → update cache.
    /// Called on appear, pull-to-refresh, and tab switch.
    func loadProducts(locationId: String, search: String? = nil) async {
        currentPage = 1
        hasMore = true
        currentSearchQuery = search
        
        // STEP 1: If no search and cache has data, show it immediately
        if (search == nil || search?.isEmpty == true) && !cache.isEmpty {
            let cached = cache.loadAll()
            if !cached.isEmpty {
                products = cached
                totalCount = cached.count
                recalculateCounts()
                recomputeFilteredProducts()
            }
        }
        
        // STEP 2: Show loading indicator and fetch fresh data from server
        isLoading = true
        currentPage = 1
        hasMore = true
        currentSearchQuery = search
        // Any explicit refresh invalidates the previous warm-up
        warmUpTask?.cancel()
        isWarmingCache = false
        
        do {
            var params: [String: String] = [
                "locationId": locationId,
                "page": "1",
                "limit": "\(pageSize)"
            ]
            if let search = search, !search.isEmpty {
                params["search"] = search
            }
            
            let response: ProductListResponse = try await apiClient.request(
                endpoint: .listProducts,
                queryParams: params
            )
            products = response.data
            totalCount = response.totalCount ?? response.count
            hasMore = response.hasMore ?? false
            currentPage = 1
            recalculateCounts()
            recomputeFilteredProducts()
            
            // STEP 3: Update cache with fresh data (skip search results)
            if search == nil || search?.isEmpty == true {
                cache.saveProducts(response.data)
                cache.markFresh()
                // STEP 4: Warm up the full catalog in the background so the
                // barcode scanner's level-1 cache lookup covers all products.
                startWarmUp(locationId: locationId)
            }
        } catch let error as NetworkError {
            // If we already have cached data, don't show error — just use cache
            if products.isEmpty {
                errorMessage = error.errorDescription ?? "Error al cargar productos"
                showError = true
            }
        } catch {
            if products.isEmpty {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        
        isLoading = false
    }
    
    /// Load next page (appends to existing products). Called by infinite scroll.
    func loadMoreProducts(locationId: String) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        do {
            var params: [String: String] = [
                "locationId": locationId,
                "page": "\(nextPage)",
                "limit": "\(pageSize)"
            ]
            if let search = currentSearchQuery, !search.isEmpty {
                params["search"] = search
            }
            
            let response: ProductListResponse = try await apiClient.request(
                endpoint: .listProducts,
                queryParams: params
            )
            
            // Append new products, avoiding duplicates
            let existingIds = Set(products.map { $0.id })
            let newProducts = response.data.filter { !existingIds.contains($0.id) }
            products.append(contentsOf: newProducts)
            
            totalCount = response.totalCount ?? totalCount
            hasMore = response.hasMore ?? false
            currentPage = nextPage
            recalculateCounts()
            recomputeFilteredProducts()
            
            // Update cache with new page
            cache.saveProducts(response.data)
        } catch {
            // Silent fail for load-more — user can scroll again to retry
            print("Failed to load more products: \(error)")
        }
        
        isLoadingMore = false
    }
    
    /// Background full-catalog warm-up: paginates pages 2..N silently and writes
    /// ONLY to the SwiftData cache (never touches `products` or the UI).
    /// Purpose: make barcode level-1 (indexed cache lookup) cover the whole catalog.
    /// Server remains source of truth — this does not replace any GET.
    private func startWarmUp(locationId: String) {
        warmUpTask?.cancel()
        let startPage = currentPage + 1
        warmUpTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isWarmingCache = true }
            var page = startPage
            var keepGoing = true
            while keepGoing {
                if Task.isCancelled { break }
                do {
                    let params: [String: String] = [
                        "locationId": locationId,
                        "page": "\(page)",
                        "limit": "\(self.pageSize)"
                    ]
                    let response: ProductListResponse = try await self.apiClient.request(
                        endpoint: .listProducts,
                        queryParams: params
                    )
                    self.cache.saveProducts(response.data)
                    await MainActor.run { self.warmUpProgress = self.cache.cachedCount }
                    keepGoing = response.hasMore ?? false
                    page += 1
                } catch {
                    // Silent fail — warm-up is best-effort; level-2 server search covers gaps
                    keepGoing = false
                }
            }
            await MainActor.run { self.isWarmingCache = false }
        }
    }
    
    /// Search products on server with exact=true for barcode scanner.
    /// Does NOT modify the main products list — returns results separately.
    func searchExact(locationId: String, code: String) async throws -> ProductListResponse {
        let params: [String: String] = [
            "locationId": locationId,
            "search": code,
            "exact": "true",
            "limit": "20"
        ]
        return try await apiClient.request(
            endpoint: .listProducts,
            queryParams: params
        )
    }
    
    /// Update a single product in the list (e.g. after detail view refresh).
    /// Write-through: updates both in-memory array AND SwiftData cache.
    func updateProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            recalculateCounts()
            recomputeFilteredProducts()
        }
        // Write-through to cache
        cache.saveProduct(product)
    }
    
    /// Insert a newly created product at the top of the list.
    /// Write-through: updates both in-memory array AND SwiftData cache.
    func insertProduct(_ product: Product) {
        products.insert(product, at: 0)
        totalCount += 1
        recalculateCounts()
        recomputeFilteredProducts()
        // Write-through to cache
        cache.saveProduct(product)
    }
    
    /// Single-pass count calculation — called once when products change
    private func recalculateCounts() {
        var c = ProductCounts()
        c.total = products.count
        for product in products {
            let stock = product.totalInventory ?? 0
            if stock == 0 { c.outOfStock += 1 }
            else if stock < 10 { c.lowStock += 1 }
            else { c.inStock += 1 }
            if (product.profitMargin ?? 100) < 10 { c.lowMargin += 1 }
            if product.hasSquareSync == true { c.synced += 1 } else { c.local += 1 }
        }
        counts = c
    }
}
