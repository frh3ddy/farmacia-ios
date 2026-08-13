import SwiftUI
import CodeScanner

// MARK: - Filter / Sort enums (file scope — used by both the view and the view model)

enum ProductFilter: String, CaseIterable {
    case all = "Todos"
    case lowStock = "Stock Bajo"
    case outOfStock = "Sin Stock"
    case inStock = "In Stock"
    case atRisk = "En Riesgo"
    case expiringSoon = "Por Vencer"
    case lowMargin = "Margen Bajo"
    
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

// MARK: - Products View
// Unified product + inventory hub. Includes search, smart filters,
// attention banner, sort options, and a toolbar link to global activity history.

struct ProductsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProductsViewModel()
    @StateObject private var agingViewModel = ProductsAgingViewModel()
    @StateObject private var expiringViewModel = ExpiringProductsViewModel()
    @State private var showCreateProduct = false
    @State private var showPurchaseOrder = false
    @State private var showShoppingLists = false
    @State private var searchText = ""
    @State private var activeFilter: ProductFilter = .all
    @State private var sortOption: ProductSortOption = .name
    
    // Barcode scanner state
    @State private var showBarcodeScanner = false
    @State private var scannedProduct: Product? = nil
    @State private var navigateToScannedProduct = false
    @State private var prefillSku: String? = nil
    
    /// Tab-switch refresh trigger (set by MainTabView)
    var refreshTrigger: UUID = UUID()
    
    // Debounced search — triggers server-side search after user stops typing
    @State private var searchTask: Task<Void, Never>? = nil
    
    // MARK: - Computed products
    // Note: name/SKU filtering is handled server-side via the `search` query param.
    // Stock/risk/margin filtering + sorting live in ProductsViewModel — recomputed
    // only when inputs change, NOT on every SwiftUI render. Read viewModel.filteredProducts.
    
    // Stock count helpers for attention banner (read from pre-computed counts)
    private var outOfStockCount: Int { viewModel.counts.outOfStock }
    private var lowStockCount: Int { viewModel.counts.lowStock }
    private var lowMarginCount: Int { viewModel.counts.lowMargin }
    private var atRiskCount: Int { agingViewModel.atRiskProductIds.count }
    
    private var needsAttention: Bool {
        outOfStockCount > 0 || lowStockCount > 0 || lowMarginCount > 0 || atRiskCount > 0
    }
    
    /// True while the user is typing a search — hides the attention banner,
    /// filter chips and summary section so results get priority on screen.
    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // Barcode scanner: multiple candidates from fuzzy server match
    @State private var barcodeCandidates: [Product] = []
    @State private var showBarcodeCandidates = false
    @State private var lastScannedCode: String = ""
    
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
                if viewModel.isLoading && viewModel.products.isEmpty {
                    loadingView
                } else if viewModel.products.isEmpty {
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
                        showBarcodeScanner = true
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

                    // Shopping Lists (primary path)
                    if authManager.canManageInventory {
                        Button {
                            showShoppingLists = true
                        } label: {
                            let activeCount = ShoppingListStore.shared.activeLists.count
                            Image(systemName: "list.clipboard")
                                .overlay(alignment: .topTrailing) {
                                    if activeCount > 0 {
                                        Text("\(activeCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 14, minHeight: 14)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }
                        .accessibilityLabel("Listas de Compras, \(ShoppingListStore.shared.activeLists.count) activas")
                    }

                    // Quick Receive (legacy fast path)
                    if authManager.canManageInventory {
                        Button {
                            showPurchaseOrder = true
                        } label: {
                            Image(systemName: "cart.badge.plus")
                        }
                        .accessibilityLabel("Recepción Rápida")
                    }

                    // Add product
                    if authManager.isOwner || authManager.isManager {
                        Button {
                            showCreateProduct = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Agregar Producto")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar productos...")
            .onChange(of: searchText) { _, newValue in
                // Debounce: cancel previous search, wait 400ms, then search server-side
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
                    guard !Task.isCancelled else { return }
                    await loadProducts()
                }
            }
            .onChange(of: activeFilter) { _, newFilter in
                viewModel.setFilter(newFilter, atRiskIds: agingViewModel.atRiskProductIds, expiringIds: expiringViewModel.expiringProductIds)
            }
            .onChange(of: sortOption) { _, newSort in
                viewModel.setSort(newSort)
            }
            .onChange(of: agingViewModel.atRiskProductIds) { _, newIds in
                // Re-apply filter when aging data arrives (atRisk filter depends on it)
                if activeFilter == .atRisk {
                    viewModel.setFilter(.atRisk, atRiskIds: newIds, expiringIds: expiringViewModel.expiringProductIds)
                }
            }
            .onChange(of: expiringViewModel.expiringProductIds) { _, newIds in
                if activeFilter == .expiringSoon {
                    viewModel.setFilter(.expiringSoon, atRiskIds: agingViewModel.atRiskProductIds, expiringIds: newIds)
                }
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
            .refreshable {
                await loadProducts()
            }
            .sheet(isPresented: $showCreateProduct) {
                CreateProductView(prefillSku: prefillSku)
                    .onDisappear {
                        prefillSku = nil
                    }
            }
            .sheet(isPresented: $showPurchaseOrder) {
                PurchaseOrderView()
            }
            .fullScreenCover(isPresented: $showShoppingLists) {
                ShoppingListsView(store: ShoppingListStore.shared)
            }
            .sheet(isPresented: $showBarcodeCandidates) {
                BarcodeCandidatesSheet(
                    code: lastScannedCode,
                    candidates: barcodeCandidates,
                    onSelect: { product in
                        showBarcodeCandidates = false
                        scannedProduct = product
                        navigateToScannedProduct = true
                    },
                    onCreate: {
                        showBarcodeCandidates = false
                        prefillSku = lastScannedCode
                        showCreateProduct = true
                    }
                )
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerSheet { scannedCode in
                    showBarcodeScanner = false
                    handleScannedBarcode(scannedCode)
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
            .task {
                await loadProducts()
                await loadAgingData()
            }
            .onChange(of: refreshTrigger) { _, _ in
                // Tab was selected — reload fresh data
                Task {
                    await loadProducts()
                }
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
                    showCreateProduct = true
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
            // Attention Banner (hidden while searching so results get priority)
            if needsAttention && !isSearching {
                Section {
                    attentionBanner
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Filter Chips (hidden while searching)
            if !isSearching {
                Section {
                    filterChips
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }
            
            // Summary Section (hidden while searching)
            if !isSearching {
            Section {
                HStack {
                    summaryItem(
                        title: "Total",
                        value: "\(viewModel.totalCount)",
                        icon: "shippingbox.fill",
                        color: .blue
                    )
                    
                    Divider()
                    
                    summaryItem(
                        title: "Sincronizado",
                        value: "\(viewModel.counts.synced)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    Divider()
                    
                    let localCount = viewModel.counts.local
                    
                    if localCount > 0 {
                        Button {
                            Task { await syncLocalProductsToSquare() }
                        } label: {
                            VStack(spacing: 4) {
                                if isSyncingToSquare {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title3)
                                        .foregroundStyle(.orange)
                                }
                                Text("\(localCount) Local")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("Sincronizar")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(isSyncingToSquare)
                    } else {
                        summaryItem(
                            title: "Local",
                            value: "0",
                            icon: "iphone",
                            color: .green
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .alert("Sincronización Square", isPresented: $showSyncResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncResultMessage ?? "")
            }
            }
            
            // Products Section
            Section {
                if viewModel.filteredProducts.isEmpty {
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
                                riskLevel: agingViewModel.productRiskLevels[product.id]
                            )
                        }
                        .onAppear {
                            // Infinite scroll: trigger load-more when near the end
                            if product.id == viewModel.filteredProducts.last?.id && viewModel.hasMore {
                                Task {
                                    await loadMoreProducts()
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
            } footer: {
                if viewModel.totalCount > 0 {
                    Text("Mostrando \(viewModel.products.count) de \(viewModel.totalCount) productos")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
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

    // MARK: - Attention Banner
    
    private var attentionBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atención Requerida")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(attentionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Quick filter buttons in the banner
            HStack(spacing: 8) {
                if outOfStockCount > 0 {
                    Button {
                        activeFilter = .outOfStock
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("\(outOfStockCount) Out of Stock")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                if lowStockCount > 0 {
                    Button {
                        activeFilter = .lowStock
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("\(lowStockCount) Low Stock")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundStyle(.orange)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                if lowMarginCount > 0 {
                    Button {
                        activeFilter = .lowMargin
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 8, height: 8)
                            Text("\(lowMarginCount) Low Margin")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundStyle(.purple)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                if atRiskCount > 0 {
                    Button {
                        activeFilter = .atRisk
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("\(atRiskCount) At Risk")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private var attentionMessage: String {
        var parts: [String] = []
        if outOfStockCount > 0 {
            parts.append("\(outOfStockCount) product\(outOfStockCount == 1 ? "" : "s") out of stock")
        }
        if lowStockCount > 0 {
            parts.append("\(lowStockCount) product\(lowStockCount == 1 ? "" : "s") running low")
        }
        if atRiskCount > 0 {
            parts.append("\(atRiskCount) at risk (aging)")
        }
        if lowMarginCount > 0 {
            parts.append("\(lowMarginCount) with low margin")
        }
        return parts.joined(separator: " \u{2022} ")
    }
    
    // MARK: - Filter Chips
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProductFilter.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.vertical, 4)
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
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption2)
                Text(filter.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if filter != .all {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            isActive ? Color.white.opacity(0.3) : filter.color.opacity(0.15)
                        )
                        .clipShape(.rect(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? filter.color : Color(.systemGray6))
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
    
    private func filterCount(for filter: ProductFilter) -> Int {
        switch filter {
        case .all: return viewModel.counts.total
        case .lowStock: return viewModel.counts.lowStock
        case .outOfStock: return viewModel.counts.outOfStock
        case .inStock: return viewModel.counts.inStock
        case .atRisk: return atRiskCount
        case .expiringSoon: return expiringViewModel.expiringProductIds.count
        case .lowMargin: return viewModel.counts.lowMargin
        }
    }
    
    // MARK: - Summary Item
    
    private func summaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadProducts() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        let search = searchText.isEmpty ? nil : searchText
        await viewModel.loadProducts(locationId: locationId, search: search)
    }
    
    private func loadMoreProducts() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await viewModel.loadMoreProducts(locationId: locationId)
    }
    
    private func loadAgingData() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        // Independent loads — fire in parallel
        async let atRiskLoad: () = agingViewModel.loadAtRiskProducts(locationId: locationId)
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
    
    private func handleScannedBarcode(_ code: String) {
        lastScannedCode = code
        let cache = ProductCacheManager.shared
        
        // LEVEL 1a: Check loaded products in memory (instant)
        if let match = viewModel.products.first(where: { $0.sku?.lowercased() == code.lowercased() }) {
            scannedProduct = match
            navigateToScannedProduct = true
            return
        }
        
        // LEVEL 1b: Check SwiftData cache (all 3000+ products, indexed)
        if let cached = cache.findBySku(code) {
            scannedProduct = cached
            navigateToScannedProduct = true
            return
        }
        
        // LEVEL 2 + 3: Server search with exact=true (does NOT touch the product list)
        Task {
            guard let locationId = authManager.currentLocation?.id else { return }
            
            do {
                let response = try await viewModel.searchExact(locationId: locationId, code: code)
                
                if response.exactMatch == true, let match = response.data.first {
                    // Exact SKU match — go straight to detail
                    scannedProduct = match
                    navigateToScannedProduct = true
                } else if response.data.count == 1 {
                    // Single fuzzy result — go straight to detail
                    scannedProduct = response.data.first
                    navigateToScannedProduct = true
                } else if response.data.count > 1 {
                    // Multiple fuzzy results — show candidates sheet
                    barcodeCandidates = response.data
                    showBarcodeCandidates = true
                } else {
                    // Not found — offer to create product
                    prefillSku = code
                    showCreateProduct = true
                }
            } catch {
                // Network error — offer to create anyway
                prefillSku = code
                showCreateProduct = true
            }
        }
    }
}

// MARK: - Barcode Scanner Sheet

private struct BarcodeScannerSheet: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .qr],
                scanMode: .once,
                showViewfinder: true,
                shouldVibrateOnSuccess: true,
                completion: handleScan
            )
            .navigationTitle("Escanear Código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let scanResult):
            onCodeScanned(scanResult.string)
        case .failure(let error):
            print("Barcode scan failed: \(error.localizedDescription)")
            dismiss()
        }
    }
}

// MARK: - Barcode Candidates Sheet (fuzzy match results)

private struct BarcodeCandidatesSheet: View {
    let code: String
    let candidates: [Product]
    let onSelect: (Product) -> Void
    let onCreate: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { product in
                        Button {
                            onSelect(product)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(.blue)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    if let sku = product.sku {
                                        Text("SKU: \(sku)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let price = product.formattedPrice {
                                        Text(price)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    if let stock = product.totalInventory {
                                        Text("\(stock) uds")
                                            .font(.caption)
                                            .foregroundStyle(stock > 0 ? Color.secondary : Color.red)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Resultados para \"\(code)\"")
                }
                
                Section {
                    Button {
                        onCreate()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Crear Producto Nuevo")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("SKU: \(code)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Seleccionar Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}


// MARK: - Preview

#Preview {
    ProductsView()
        .environmentObject(AuthManager.shared)
}
