import Foundation
import FarmaciaKit

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
    /// The list's last load failed with nothing of it on screen (empty row says so).
    @Published private(set) var loadFailed = false
    
    // Filter/sync badge counts. Backed by the server aggregate (GET
    // /products/counts, whole catalog) whenever it's available; falls back
    // to a page-based estimate from `products` only if that request fails.
    @Published var counts = ProductCounts()
    
    // Background catalog warm-up state (for non-blocking progress indicator)
    @Published var isWarmingCache = false
    @Published var warmUpProgress: Int = 0
    
    // Pagination state: which query and page the list shows, and which load may land
    private var load = ProductListLoad()
    var hasMore: Bool { load.hasMore }
    private(set) var totalCount = 0
    private let pageSize = 50

    // Location of the last load (for count refreshes after an edit)
    private var currentLocationId: String?
    
    // Sort input — recompute filteredProducts only when it changes. Filtering is
    // the server's (the filter is part of `ProductListQuery`).
    private var activeSort: ProductSortOption = .name
    
    // Background warm-up task (cancelled on refresh/search)
    /// The running cache sync and its store; a reload never restarts it (see syncCache).
    private var syncTask: (id: UUID, locationId: String, task: Task<Void, Never>)?
    
    private let apiClient = APIClient.shared
    private let cache = ProductCacheManager.shared
    
    // MARK: - Sort (recomputed only on input change, NOT per render)

    /// The list shows the plain catalog (no search, no filter): the only one with
    /// the big loading / "Sin Productos" states, and served from cache.
    var isCatalog: Bool { load.query?.isCatalog ?? true }

    func setSort(_ sort: ProductSortOption) {
        activeSort = sort
        recomputeFilteredProducts()
    }
    
    private func recomputeFilteredProducts() {
        var result = products

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
    /// Called on appear, pull-to-refresh, search and tab switch. Starting a new load makes
    /// any load still in flight stale: its result is dropped (`ProductListLoad`).
    func loadProducts(_ query: ProductListQuery) async {
        let ticket = load.beginFirstPage(query)
        let locationId = query.locationId
        currentLocationId = locationId
        isLoadingMore = false // a pending load-more is stale now
        loadFailed = false

        // A reload of the list on screen (refresh, coming back from a product) keeps
        // its rows and scroll position. Any other list must not show the previous
        // one's rows while its own load: the catalog shows the cache, the rest start empty.
        if load.shownQuery != query {
            let cached = query.isCatalog && !cache.isEmpty ? cache.loadAll() : []
            if cached.isEmpty {
                products = []
                recomputeFilteredProducts()
                load.showRows(of: nil)
            } else {
                // STEP 1: plain catalog and the cache has data: show it immediately
                load.showRows(of: query)
                products = cached
                // Keep catalog-wide server counts when we already have them
                // (e.g. clearing a search) — a page-based estimate here makes
                // the stats/local-sync rows flicker until the server responds.
                if counts.total > 0 {
                    totalCount = counts.total
                } else {
                    totalCount = cached.count
                    recalculateCounts()
                }
                recomputeFilteredProducts()
            }
        }

        // STEP 2: Show loading indicator and fetch fresh data from server
        isLoading = true
        do {
            let params = query.params(page: 1, limit: pageSize)

            // Counts come from the server aggregate (GET /products/counts) —
            // a single query over the whole catalog, not just this page.
            // Fetched alongside the page request rather than sequentially.
            async let pageFetch: ProductListResponse = apiClient.request(
                endpoint: .listProducts,
                queryParams: params
            )
            async let countsFetch: ProductCountsResponse? = try? apiClient.request(
                endpoint: .productCounts,
                queryParams: ["locationId": locationId]
            )

            let response = try await pageFetch
            let serverCounts = await countsFetch
            guard load.accept(ticket, hasMore: response.hasMore ?? false) else { return }

            products = response.data
            // "Todos" counts the catalog (or the search), never a filtered list.
            if query.filter == nil {
                totalCount = response.totalCount ?? response.count
            }
            recomputeFilteredProducts()

            if let serverCounts {
                applyServerCounts(serverCounts)
            } else if query.isCatalog {
                // Counts endpoint failed — fall back to a page-based estimate.
                recalculateCounts()
            }

            // STEP 3: Bring the cache up to date (plain catalog only), so the
            // barcode scanner's level-1 cache lookup covers all products.
            if query.isCatalog {
                syncCache(locationId: locationId)
            }
        } catch {
            guard load.fail(ticket) else { return }
            isLoading = false
            // Cancelled (search changed, view left): not an error. Rows of this same
            // list on screen (cache, or before a refresh) stay, without one either.
            if NetworkError.isCancellation(error) || (load.shownQuery == query && !products.isEmpty) { return }
            // Nothing on screen may look like this list's results — and its empty
            // row says it couldn't load, not "no matches".
            products = []
            recomputeFilteredProducts()
            load.showRows(of: nil)
            loadFailed = true
            if let error = error as? NetworkError {
                errorMessage = error.errorDescription ?? "Error al cargar productos"
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
            return
        }

        isLoading = false
    }

    /// Load next page (appends to existing products). Called by infinite scroll.
    func loadMoreProducts() async {
        guard let ticket = load.beginNextPage() else { return }
        isLoadingMore = true

        do {
            let params = ticket.query.params(page: ticket.page, limit: pageSize)

            let response: ProductListResponse = try await apiClient.request(
                endpoint: .listProducts,
                queryParams: params
            )
            // A search or refresh started meanwhile: this page belongs to the old list.
            guard load.accept(ticket, hasMore: response.hasMore ?? false) else { return }

            // Append new products, avoiding duplicates
            let existingIds = Set(products.map { $0.id })
            let newProducts = response.data.filter { !existingIds.contains($0.id) }
            products.append(contentsOf: newProducts)

            if ticket.query.filter == nil {
                totalCount = response.totalCount ?? totalCount
            }
            // Counts already reflect the whole catalog via the server aggregate —
            // recomputing from `products` here would regress them to a partial,
            // page-based estimate.
            recomputeFilteredProducts()

            // Update cache with new page (catalog pages only, like page 1)
            if ticket.query.isCatalog {
                cache.saveProducts(response.data)
            }
        } catch {
            // Silent fail for load-more — user can scroll again to retry
            guard load.fail(ticket) else { return }
            if !NetworkError.isCancellation(error) { print("Failed to load more products: \(error)") }
        }

        isLoadingMore = false
    }

    /// Brings the on-device cache up to date with GET /products/sync (ProductSync): usually
    /// one small request. Only the first sync at a store, or a cursor the server rejects,
    /// walks the whole catalog (the banner). A sync still running isn't restarted by a
    /// reload — cancelling it on every tab switch kept the old full walk from finishing —
    /// only by a store switch.
    private func syncCache(locationId: String) {
        if let running = syncTask {
            guard running.locationId != locationId else { return }
            running.task.cancel()
        }
        let scope = ProductCacheScope(locationId: locationId)
        let storedCursor = cache.syncCursor(for: scope)
        isWarmingCache = storedCursor == nil
        warmUpProgress = 0
        let id = UUID()
        let task = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let result = try await ProductSync.run(from: storedCursor) { cursor in
                    try Task.checkCancellation()
                    var params = ["locationId": locationId]
                    if let cursor { params["cursor"] = cursor }
                    let response: ProductSyncResponse = try await self.apiClient.request(
                        endpoint: .productDeltaSync,
                        queryParams: params
                    )
                    self.warmUpProgress += response.data.count
                    return ProductSyncPage(rows: response.data, removedIds: response.removedIds,
                                           cursor: response.cursor, hasMore: response.hasMore)
                }
                if !Task.isCancelled { self.cache.applySync(result, for: scope) }
            } catch {
                // Best effort: the stored cursor stays and the next sync resumes from it;
                // the scanner's level-2 server search covers gaps meanwhile.
            }
            if self.syncTask?.id == id {
                self.syncTask = nil
                self.isWarmingCache = false
            }
        }
        syncTask = (id, locationId, task)
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
            recomputeFilteredProducts()
        }
        // Write-through to cache
        cache.saveProduct(product)
        refreshServerCounts()
    }

    /// Insert a newly created product at the top of the list.
    /// Write-through: updates both in-memory array AND SwiftData cache.
    func insertProduct(_ product: Product) {
        products.insert(product, at: 0)
        totalCount += 1
        recomputeFilteredProducts()
        // Write-through to cache
        cache.saveProduct(product)
        refreshServerCounts()
    }

    /// Re-fetch the server-wide count aggregate after a single-product edit —
    /// cheaper and more correct than patching `counts` from just the edited
    /// item, since the old bucket it moved out of isn't known locally.
    private func refreshServerCounts() {
        guard let locationId = currentLocationId else { return }
        Task {
            if let serverCounts: ProductCountsResponse = try? await apiClient.request(
                endpoint: .productCounts,
                queryParams: ["locationId": locationId]
            ) {
                applyServerCounts(serverCounts)
            }
        }
    }

    private func applyServerCounts(_ response: ProductCountsResponse) {
        var c = ProductCounts()
        c.total = response.total
        c.outOfStock = response.outOfStock
        c.lowStock = response.lowStock
        c.inStock = response.total - response.outOfStock - response.lowStock
        c.lowMargin = response.lowMargin ?? 0
        c.synced = response.synced
        c.local = response.local
        counts = c
    }
    
    /// Single-pass count calculation over a given product list. Only used as
    /// a fallback (cache-first optimistic display, or if GET /products/counts
    /// fails) — it necessarily undercounts against the whole catalog since
    /// `products` only holds however many pages have loaded so far.
    private func computeCounts(from source: [Product]) -> ProductCounts {
        var c = ProductCounts()
        c.total = source.count
        for product in source {
            let stock = product.totalInventory ?? 0
            if stock == 0 { c.outOfStock += 1 }
            else if stock < 10 { c.lowStock += 1 }
            else { c.inStock += 1 }
            if (product.profitMargin ?? 100) < 10 { c.lowMargin += 1 }
            if product.hasSquareSync == true { c.synced += 1 } else { c.local += 1 }
        }
        return c
    }

    private func recalculateCounts() {
        counts = computeCounts(from: products)
    }
}
