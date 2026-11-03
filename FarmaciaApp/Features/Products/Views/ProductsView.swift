import SwiftUI
import FarmaciaKit

// MARK: - Filter / Sort enums (file scope — used by both the view and the view model)

// Cases, visibility per role and empty-state text live in FarmaciaKit.
extension ProductFilter {
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .lowStock: return "exclamationmark.triangle"
        case .outOfStock: return "xmark.circle"
        case .inStock: return "checkmark.circle"
        case .atRisk: return "exclamationmark.octagon"
        case .expiringSoon: return "clock.badge.exclamationmark"
        case .lowMargin: return "percent"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .lowStock: return .orange
        case .outOfStock: return .red
        case .inStock: return .green
        case .atRisk: return .red
        case .expiringSoon: return .orange
        case .lowMargin: return .purple
        }
    }
}

enum ProductSortOption: String, CaseIterable {
    case name = "Nombre"
    case stockAsc = "Stock (Low)"
    case stockDesc = "Stock (High)"
    case margin = "Margen"
    case priceAsc = "Precio (Menor)"
    case priceDesc = "Precio (Mayor)"
}

// MARK: - Products Sheet
// What Productos presents, on one `sheet(item:)`: a new product, or the scan
// flow (which itself goes on to the candidates or a new product with the
// scanned SKU — see ScanFlowSheet). One item, so the sheet and its data land in
// the same transaction, and two sheets can never compete for the screen.
private enum ProductsSheet: Identifiable {
    case newProduct
    case scan

    var id: String {
        switch self {
        case .newProduct: "newProduct"
        case .scan: "scan"
        }
    }
}

// MARK: - Products View
// Unified product + inventory hub. Includes search, smart filters,
// attention banner, sort options, and a toolbar link to global activity history.

struct ProductsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProductsViewModel()
    @StateObject private var agingViewModel = ProductsAgingViewModel()
    @StateObject private var expiringViewModel = ExpiringProductsViewModel()
    @State private var sheet: ProductsSheet?
    @State private var offlineQueue = OfflineQueueManager.shared
    @State private var searchText = ""
    @State private var activeFilter: ProductFilter = .all
    @State private var sortOption: ProductSortOption = .name

    // A scanned product opens here (the scan flow closes its sheet first)
    @State private var scannedProduct: Product? = nil
    @State private var navigateToScannedProduct = false
    
    /// Tab-switch refresh trigger (set by MainTabView)
    var refreshTrigger: UUID = UUID()

    /// What the list shows. Changing it (typing, clearing the search, picking a chip,
    /// switching location or tab) cancels the previous load task and starts the next one.
    private struct ListLoadKey: Equatable {
        let query: ProductListQuery?
        let refresh: UUID
    }

    private var listLoadKey: ListLoadKey {
        ListLoadKey(
            // Coerced here too, so a store switch never sends a chip the new role can't use
            // (the onChange below then moves the selection itself back to Todos).
            query: authManager.currentLocation.map {
                ProductListQuery(locationId: $0.id, search: searchText,
                                 filter: .coerced(activeFilter, canViewCosts: authManager.canViewCosts))
            },
            refresh: refreshTrigger
        )
    }
    
    // MARK: - Computed products
    // Note: name/SKU filtering is handled server-side via the `search` query param.
    // Stock/risk/margin filtering + sorting live in ProductsViewModel — recomputed
    // only when inputs change, NOT on every SwiftUI render. Read viewModel.filteredProducts.
    
    /// The ids behind the En Riesgo / Por Vencer chips (other filters don't use them).
    private func riskSet(for filter: ProductFilter) -> RiskSet {
        switch filter {
        case .atRisk: return agingViewModel.atRisk
        case .expiringSoon: return expiringViewModel.expiring
        default: return .loading
        }
    }

    /// True while the user is typing a search — hides the filter chips
    /// and summary section so results get priority on screen.
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    
    // Square bulk sync
    @State private var isSyncingToSquare = false
    @State private var syncResultMessage: String?
    @State private var showSyncResult = false

    // Catalog warm-up banner — delayed so a warm-up that finishes almost
    // instantly (already-cached catalog) never flashes the indicator.
    @State private var showSyncBanner = false
    @State private var syncBannerDelayTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Group {
                // Whole-screen states are for the plain catalog; a search or chip
                // with no matches keeps the list (and its chips) on screen.
                if viewModel.isCatalog && viewModel.isLoading && viewModel.products.isEmpty {
                    loadingView
                } else if viewModel.isCatalog && viewModel.products.isEmpty && !viewModel.loadFailed {
                    emptyStateView
                } else {
                    productsList
                }
            }
            .navigationTitle("Productos")
            .toolbar {
                // Activity history (left)
                ToolbarItem(placement: .topBarLeading) {
                    if authManager.canManageInventory {
                        NavigationLink {
                            GlobalActivityHistoryView()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel("Historial de Actividad")
                    }
                }

                // Sort + Purchase Order + Add (right)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Barcode scanner
                    Button {
                        sheet = .scan
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    .accessibilityLabel("Escanear Código de Barras")

                    // Sort menu — uses Picker to avoid SwiftUI Menu+ForEach first-item bug
                    Menu {
                        Picker("Ordenar por", selection: $sortOption) {
                            ForEach(ProductSortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                    .accessibilityLabel("Ordenar")

                    // Add product
                    if authManager.isOwner || authManager.isManager {
                        Button {
                            sheet = .newProduct
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Agregar Producto")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar productos...")
            .onChange(of: sortOption) { _, newSort in
                viewModel.setSort(newSort)
            }
            .onChange(of: authManager.canViewCosts) { _, canViewCosts in
                // e.g. switched to a store where this employee is a cashier: no hidden chip stays active
                activeFilter = .coerced(activeFilter, canViewCosts: canViewCosts)
            }
            .onChange(of: viewModel.isWarmingCache) { _, isWarming in
                syncBannerDelayTask?.cancel()
                if isWarming {
                    syncBannerDelayTask = Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                        guard !Task.isCancelled else { return }
                        showSyncBanner = true
                    }
                } else {
                    showSyncBanner = false
                }
            }
            .onChange(of: offlineQueue.pendingCount) { oldValue, newValue in
                // A queued write just synced (e.g. a product created offline):
                // reload, so it shows up without a manual refresh.
                if newValue < oldValue {
                    Task { await loadProducts() }
                }
            }
            .refreshable {
                async let products: () = loadProducts()
                async let aging: () = loadAgingData()
                _ = await (products, aging)
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .newProduct:
                    CreateProductView(onCreated: viewModel.upsertProduct)
                case .scan:
                    ScanFlowSheet(
                        lookup: lookupScannedCode,
                        onOpen: { product in
                            scannedProduct = product
                            navigateToScannedProduct = true
                        },
                        onCreated: viewModel.upsertProduct
                    )
                }
            }
            .navigationDestination(isPresented: $navigateToScannedProduct) {
                if let product = scannedProduct {
                    ProductDetailView(
                        product: product,
                        onProductUpdated: { updatedProduct in
                            viewModel.updateProduct(updatedProduct)
                        }
                    )
                }
            }
            .task(id: listLoadKey) {
                guard let query = listLoadKey.query else { return }
                if query.search != nil {
                    // Debounce typing: the next keystroke cancels this task during the sleep.
                    do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
                }
                await viewModel.loadProducts(query)
            }
            .onChange(of: authManager.currentLocation?.id) {
                // Nothing from the previous store (or role) shows while this one loads.
                agingViewModel.reset()
                expiringViewModel.reset()
            }
            .task(id: authManager.currentLocation?.id) {
                await loadAgingData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
                Button("Reintentar") {
                    Task {
                        await loadProducts()
                    }
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Cargando productos...")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Sin Productos")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Products synced from Square will appear here.\nYou can also create products manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if authManager.isOwner || authManager.isManager {
                Button {
                    sheet = .newProduct
                } label: {
                    Label("Crear Producto", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Products List
    
    private var productsList: some View {
        List {
            // Chips, stats and (optional) local sync row share a single Section —
            // insetGrouped List style adds its own gap *between* Sections, so
            // splitting these into separate Sections was stacking that gap
            // three times over. One Section + manual VStack spacing instead.
            if !isSearching {
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        filterChips
                            .padding(.bottom, 14)

                        if let summary = viewModel.syncSummary {
                            statsRow(summary)
                        }

                        if viewModel.counts.local > 0 {
                            localSyncRow
                                .padding(.top, 6)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }

            // Products Section
            Section {
                if viewModel.filteredProducts.isEmpty && viewModel.isLoading {
                    ProgressView("Cargando productos...")
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .listRowBackground(Color.clear)
                } else if viewModel.filteredProducts.isEmpty && viewModel.loadFailed {
                    // Not "no matches": this list didn't load.
                    AppEmptyStateView(
                        title: "No Disponible",
                        systemImage: "wifi.exclamationmark",
                        message: "No se pudo cargar esta lista. Desliza hacia abajo para reintentar."
                    )
                    .frame(minHeight: 240)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else if viewModel.filteredProducts.isEmpty {
                    // Distinct from the catalog-wide empty state above this
                    // Group's other branch — this is "no results for the
                    // current search/filter", not "no products at all".
                    AppEmptyStateView(
                        title: "Sin Resultados",
                        systemImage: "magnifyingglass",
                        message: "Ningún producto coincide con tu búsqueda o filtro."
                    )
                    .frame(minHeight: 240)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.filteredProducts) { product in
                        NavigationLink {
                            ProductDetailView(
                                product: product,
                                onProductUpdated: { updatedProduct in
                                    viewModel.updateProduct(updatedProduct)
                                }
                            )
                        } label: {
                            ProductRow(
                                product: product,
                                riskLevel: agingViewModel.productRiskLevels[product.id],
                                showsMargin: authManager.canViewCosts
                            )
                        }
                        .onAppear {
                            // Infinite scroll: trigger load-more when near the end
                            if product.id == viewModel.filteredProducts.last?.id && viewModel.hasMore {
                                Task {
                                    await viewModel.loadMoreProducts()
                                }
                            }
                        }
                    }

                    // Loading indicator at bottom while fetching next page
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                }
            } header: {
                // Renders nothing (no reserved header row) unless there's
                // actually a filter/search/sort indicator to show — an empty
                // HStack here was reserving header height even with no text,
                // which read as extra dead space above the product cards.
                if activeFilter != .all || !searchText.isEmpty || sortOption != .name {
                    HStack {
                        if activeFilter != .all {
                            Text("\(viewModel.filteredProducts.count) \(activeFilter.rawValue)")
                        } else if !searchText.isEmpty {
                            Text("\(viewModel.filteredProducts.count) resultados")
                        }

                        Spacer()

                        if sortOption != .name {
                            Text("Ordenado por: \(sortOption.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                if viewModel.totalCount > 0 {
                    Text("Mostrando \(viewModel.products.count) de \(viewModel.totalCount) productos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        // insetGrouped adds its own gap between Sections on top of row insets —
        // that's what was creating the large empty band above the product
        // cards. Compact it so the info block sits close to the list.
        .listSectionSpacing(.compact)
        // Docked outside the List's own content (rather than as a Section row)
        // so it never inserts/removes a row — which was reflowing every row
        // below it and producing a visible jump each time cache warm-up
        // toggled on/off, e.g. right after popping back from ProductDetailView.
        .safeAreaInset(edge: .bottom) {
            if showSyncBanner {
                syncBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSyncBanner)
        .alert("Sincronización Square", isPresented: $showSyncResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncResultMessage ?? "")
        }
    }

    // MARK: - Catalog Warm-Up Banner

    /// Non-blocking background sync indicator. The scanner's level-2 server
    /// exact search covers products not yet cached, so the user can keep
    /// working normally while this runs.
    private var syncBanner: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Sincronizando catálogo... (\(viewModel.warmUpProgress) de \(viewModel.totalCount))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Filter Chips
    // Compact single-row chips — this is the only "attention" surface left in
    // the list body (each chip's badge count/color mirrors what a separate
    // attention banner used to spell out). Dashboard owns cross-tab alerting.

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ProductFilter.visible(canViewCosts: authManager.canViewCosts), id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(_ filter: ProductFilter) -> some View {
        let isActive = activeFilter == filter
        let count = filterCount(for: filter)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeFilter = filter
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: filter.icon)
                    .font(.system(size: 10))
                Text(filter.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)

                if filter != .all {
                    Text(count.map(String.init) ?? "—")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            isActive ? Color.white.opacity(0.3) : filter.color.opacity(0.15)
                        )
                        .clipShape(.rect(cornerRadius: 3))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(isActive ? filter.color : Color(.systemGray6))
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    /// nil while the chip's ids are loading or failed to load (shown as "—").
    private func filterCount(for filter: ProductFilter) -> Int? {
        switch filter {
        case .all: return viewModel.totalCount
        case .lowStock: return viewModel.counts.lowStock
        case .outOfStock: return viewModel.counts.outOfStock
        case .inStock: return viewModel.counts.inStock
        case .atRisk, .expiringSoon: return riskSet(for: filter).count
        case .lowMargin: return viewModel.counts.lowMargin
        }
    }

    // MARK: - Stats Row
    // Replaces the old 3-column summary card. Sits right below the filter
    // chips (not the footer) so it's visible without scrolling past the
    // whole product list.

    private func statsRow(_ summary: String) -> some View {
        Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Local Sync Row
    // Only appears when there's actually something unsynced to act on.

    private var localSyncRow: some View {
        Button {
            Task { await syncLocalProductsToSquare() }
        } label: {
            HStack(spacing: 8) {
                if isSyncingToSquare {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                }

                let localCount = viewModel.counts.local
                Text("\(localCount) producto\(localCount == 1 ? "" : "s") local\(localCount == 1 ? "" : "es") sin sincronizar")
                    .font(.caption)
                    .foregroundStyle(.primary)

                Spacer()

                Text("Sincronizar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.orange.opacity(0.1))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isSyncingToSquare)
    }

    // MARK: - Actions
    
    private func loadProducts() async {
        guard let query = listLoadKey.query else { return }
        await viewModel.loadProducts(query)
    }
    
    private func loadAgingData() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        // Independent loads — fire in parallel
        // En Riesgo is a cost view (cash tied up): cashiers neither get the chip nor the load.
        let canViewCosts = authManager.canViewCosts
        async let atRiskLoad: () = canViewCosts ? agingViewModel.loadAtRiskProducts(locationId: locationId) : ()
        async let expiringLoad: () = expiringViewModel.loadExpiringProducts(locationId: locationId)
        _ = await (atRiskLoad, expiringLoad)
    }
    
    private func syncLocalProductsToSquare() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        isSyncingToSquare = true
        
        do {
            let response: SyncToSquareResponse = try await APIClient.shared.request(
                endpoint: .syncProductsToSquare,
                body: ["locationId": locationId]
            )
            syncResultMessage = response.message ?? "Sincronización completada: \(response.data?.synced ?? 0) productos sincronizados"
            showSyncResult = true
            // Reload products to reflect updated sync status
            await loadProducts()
        } catch {
            syncResultMessage = "Error al sincronizar: \(error.localizedDescription)"
            showSyncResult = true
        }
        
        isSyncingToSquare = false
    }
    
    /// What a scanned code is: one product (open it), several (choose), or
    /// none (create one with the code as SKU). Loaded products and the on-device
    /// cache first; the server's exact search when they can't settle it.
    private func lookupScannedCode(_ code: String) async -> ScanOutcome {
        // LEVEL 1a: loaded products in memory (instant), then LEVEL 1b: the SwiftData
        // cache (whole catalog, indexed). Open a product only if it's the one match:
        // a barcode shared by several goes to the server, which lists them all.
        let lowered = code.lowercased()
        let inMemory = viewModel.products.filter { $0.sku?.lowercased() == lowered }
        let cached = ProductCacheManager.shared.findBySku(code)
        // The cache can know a second product with this barcode that isn't loaded yet.
        let matches = cached.count > inMemory.count ? cached : inMemory
        if BarcodeLookup.cacheDecision(matchCount: matches.count) == .open, let match = matches.first {
            return .open(match)
        }

        // LEVEL 2 + 3: Server search with exact=true (does NOT touch the product list)
        guard let locationId = authManager.currentLocation?.id else { return .create }
        do {
            let response = try await viewModel.searchExact(locationId: locationId, code: code)
            switch BarcodeLookup.serverDecision(exactMatch: response.exactMatch, resultCount: response.data.count) {
            case .open:
                return response.data.first.map(ScanOutcome.open) ?? .create
            case .choose:
                return .choose(response.data)
            case .create:
                return .create
            }
        } catch {
            // Network error — offer to create anyway
            return .create
        }
    }
}

// MARK: - Preview

#Preview {
    ProductsView()
        .environmentObject(AuthManager.shared)
}
