import SwiftUI
import CodeScanner

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
    
    // MARK: - Filter / Sort enums
    
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
    
    // Debounced search — triggers server-side search after user stops typing
    @State private var searchTask: Task<Void, Never>? = nil
    
    // MARK: - Computed products
    // Note: name/SKU filtering is handled server-side via the `search` query param.
    // Only stock/risk/margin filters are applied client-side on the loaded page.
    
    private var filteredProducts: [Product] {
        var products = viewModel.products
        
        // Apply client-side filter (stock, risk, margin — not name/sku)
        switch activeFilter {
        case .all:
            break
        case .lowStock:
            products = products.filter { ($0.totalInventory ?? 0) > 0 && ($0.totalInventory ?? 0) < 10 }
        case .outOfStock:
            products = products.filter { ($0.totalInventory ?? 0) == 0 }
        case .inStock:
            products = products.filter { ($0.totalInventory ?? 0) >= 10 }
        case .atRisk:
            let atRiskIds = agingViewModel.atRiskProductIds
            products = products.filter { atRiskIds.contains($0.id) }
        case .expiringSoon:
            let expiringIds = expiringViewModel.expiringProductIds
            products = products.filter { expiringIds.contains($0.id) }
        case .lowMargin:
            products = products.filter { ($0.profitMargin ?? 100) < 10 }
        }
        
        // Apply sort
        switch sortOption {
        case .name:
            products.sort { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        case .stockAsc:
            products.sort { ($0.totalInventory ?? 0) < ($1.totalInventory ?? 0) }
        case .stockDesc:
            products.sort { ($0.totalInventory ?? 0) > ($1.totalInventory ?? 0) }
        case .margin:
            products.sort { ($0.profitMargin ?? 0) > ($1.profitMargin ?? 0) }
        case .priceAsc:
            products.sort { ($0.sellingPrice ?? 0) < ($1.sellingPrice ?? 0) }
        case .priceDesc:
            products.sort { ($0.sellingPrice ?? 0) > ($1.sellingPrice ?? 0) }
        }
        
        return products
    }
    
    // Stock count helpers for attention banner
    private var outOfStockCount: Int {
        viewModel.products.filter { ($0.totalInventory ?? 0) == 0 }.count
    }
    
    private var lowStockCount: Int {
        viewModel.products.filter { ($0.totalInventory ?? 0) > 0 && ($0.totalInventory ?? 0) < 10 }.count
    }
    
    private var lowMarginCount: Int {
        viewModel.products.filter { ($0.profitMargin ?? 100) < 10 }.count
    }
    
    private var atRiskCount: Int {
        agingViewModel.atRiskProductIds.count
    }
    
    private var needsAttention: Bool {
        outOfStockCount > 0 || lowStockCount > 0 || lowMarginCount > 0 || atRiskCount > 0
    }
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if authManager.canManageInventory {
                        NavigationLink {
                            GlobalActivityHistoryView()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
                
                // Sort + Purchase Order + Add (right)
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Barcode scanner
                    Button {
                        showBarcodeScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                    
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
                                            .foregroundColor(.white)
                                            .frame(minWidth: 14, minHeight: 14)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 6, y: -6)
                                    }
                                }
                        }
                    }
                    
                    // Quick Receive (legacy fast path)
                    if authManager.canManageInventory {
                        Button {
                            showPurchaseOrder = true
                        } label: {
                            Image(systemName: "cart.badge.plus")
                        }
                    }
                    
                    // Add product
                    if authManager.isOwner || authManager.isManager {
                        Button {
                            showCreateProduct = true
                        } label: {
                            Image(systemName: "plus")
                        }
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
            .refreshable {
                await loadProducts()
            }
            .sheet(isPresented: $showCreateProduct) {
                CreateProductView(prefillSku: prefillSku)
                    .onDisappear {
                        prefillSku = nil
                        Task {
                            await loadProducts()
                        }
                    }
            }
            .sheet(isPresented: $showPurchaseOrder) {
                PurchaseOrderView()
                    .onDisappear {
                        Task {
                            await loadProducts()
                        }
                    }
            }
            .fullScreenCover(isPresented: $showShoppingLists) {
                ShoppingListsView(store: ShoppingListStore.shared)
                    .onDisappear {
                        Task {
                            await loadProducts()
                        }
                    }
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
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Sin Productos")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Products synced from Square will appear here.\nYou can also create products manually.")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
            // Attention Banner
            if needsAttention {
                Section {
                    attentionBanner
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Filter Chips
            Section {
                filterChips
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
            
            // Summary Section
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
                        value: "\(viewModel.products.filter { $0.hasSquareSync == true }.count)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    Divider()
                    
                    summaryItem(
                        title: "Local",
                        value: "\(viewModel.products.filter { $0.hasSquareSync != true }.count)",
                        icon: "iphone",
                        color: .orange
                    )
                }
                .padding(.vertical, 8)
            }
            
            // Products Section
            Section {
                ForEach(filteredProducts) { product in
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
                        if product.id == filteredProducts.last?.id && viewModel.hasMore {
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
            } header: {
                HStack {
                    if activeFilter != .all {
                        Text("\(filteredProducts.count) \(activeFilter.rawValue)")
                    } else if !searchText.isEmpty {
                        Text("\(filteredProducts.count) resultados")
                    }
                    
                    Spacer()
                    
                    if sortOption != .name {
                        Text("Ordenado por: \(sortOption.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                if viewModel.totalCount > 0 {
                    Text("Mostrando \(viewModel.products.count) de \(viewModel.totalCount) productos")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Attention Banner
    
    private var attentionBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atención Requerida")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(attentionMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.red)
                        .cornerRadius(8)
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
                        .foregroundColor(.orange)
                        .cornerRadius(8)
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
                        .foregroundColor(.purple)
                        .cornerRadius(8)
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
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? filter.color : Color(.systemGray6))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
    
    private func filterCount(for filter: ProductFilter) -> Int {
        switch filter {
        case .all: return viewModel.products.count
        case .lowStock: return lowStockCount
        case .outOfStock: return outOfStockCount
        case .inStock: return viewModel.products.filter { ($0.totalInventory ?? 0) >= 10 }.count
        case .atRisk: return atRiskCount
        case .expiringSoon: return expiringViewModel.expiringProductIds.count
        case .lowMargin: return lowMarginCount
        }
    }
    
    // MARK: - Summary Item
    
    private func summaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
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
        await agingViewModel.loadAtRiskProducts(locationId: locationId)
        await expiringViewModel.loadExpiringProducts(locationId: locationId)
    }
    
    private func handleScannedBarcode(_ code: String) {
        // First check loaded products by SKU
        if let match = viewModel.products.first(where: { $0.sku?.lowercased() == code.lowercased() }) {
            // Found in current page — navigate to product detail
            scannedProduct = match
            navigateToScannedProduct = true
        } else {
            // Not in current page — try server-side search
            Task {
                guard let locationId = authManager.currentLocation?.id else { return }
                await viewModel.loadProducts(locationId: locationId, search: code)
                
                if let match = viewModel.products.first(where: { $0.sku?.lowercased() == code.lowercased() }) {
                    scannedProduct = match
                    navigateToScannedProduct = true
                    // Restore full list after navigating
                    await viewModel.loadProducts(locationId: locationId)
                } else {
                    // Not found — open create product with SKU prefilled
                    prefillSku = code
                    showCreateProduct = true
                    // Restore full list
                    await viewModel.loadProducts(locationId: locationId)
                }
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

// MARK: - Product Row (Enhanced with stock badges and margin)

struct ProductRow: View {
    let product: Product
    var riskLevel: InventoryRiskLevel? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image or Placeholder
            if let imageUrl = product.squareImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        productPlaceholder
                    @unknown default:
                        productPlaceholder
                    }
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                productPlaceholder
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let sku = product.sku {
                        Text(sku)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if product.hasSquareSync == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    
                    // Stock badge
                    stockBadge
                    
                    // Risk badge (from aging service)
                    if let risk = riskLevel, risk == .high || risk == .critical {
                        Text(risk == .critical ? "CRIT" : "RISK")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(risk.color.opacity(0.15))
                            .foregroundColor(risk.color)
                            .cornerRadius(3)
                    }
                }
            }
            
            Spacer()
            
            // Price, Margin, and Stock
            VStack(alignment: .trailing, spacing: 4) {
                if let price = product.formattedPrice {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Margin indicator
                if let margin = product.profitMargin {
                    Text(String(format: "%.0f%%", margin))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(marginColor(margin).opacity(0.15))
                        .foregroundColor(marginColor(margin))
                        .cornerRadius(4)
                }
                
                if let stock = product.totalInventory {
                    Text("\(stock) uds")
                        .font(.caption)
                        .foregroundColor(stock > 0 ? .secondary : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stockBadge: some View {
        Group {
            let stock = product.totalInventory ?? 0
            if stock == 0 {
                Text("OUT")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(3)
            } else if stock < 10 {
                Text("LOW")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(3)
            }
        }
    }
    
    private func marginColor(_ margin: Double) -> Color {
        if margin >= 20 { return .green }
        if margin >= 10 { return .orange }
        return .red
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
            
            Image(systemName: "shippingbox")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Products View Model (paginated, infinite scroll)

@MainActor
class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // Pagination state
    private(set) var currentPage = 1
    private(set) var hasMore = true
    private(set) var totalCount = 0
    private let pageSize = 50
    
    // Search state (server-side)
    private var currentSearchQuery: String?
    
    private let apiClient = APIClient.shared
    
    /// Load first page (resets pagination). Called on appear, pull-to-refresh, and tab switch.
    func loadProducts(locationId: String, search: String? = nil) async {
        isLoading = true
        currentPage = 1
        hasMore = true
        currentSearchQuery = search
        
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
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Error al cargar productos"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
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
        } catch {
            // Silent fail for load-more — user can scroll again to retry
            print("Failed to load more products: \(error)")
        }
        
        isLoadingMore = false
    }
    
    /// Update a single product in the list (e.g. after detail view refresh)
    func updateProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        }
    }
}

// MARK: - Products Aging ViewModel (loads at-risk product IDs from aging service)

@MainActor
class ProductsAgingViewModel: ObservableObject {
    @Published var atRiskProductIds: Set<String> = []
    @Published var productRiskLevels: [String: InventoryRiskLevel] = [:]
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    /// Load products with HIGH or CRITICAL risk from the aging service
    func loadAtRiskProducts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ProductAgingResponse = try await apiClient.request(
                endpoint: .agingProducts,
                queryParams: [
                    "locationId": locationId,
                    "limit": "500"
                ]
            )
            
            var riskIds = Set<String>()
            var riskMap: [String: InventoryRiskLevel] = [:]
            
            for product in response.products {
                riskMap[product.productId] = product.riskLevel
                if product.riskLevel == .high || product.riskLevel == .critical {
                    riskIds.insert(product.productId)
                }
            }
            
            atRiskProductIds = riskIds
            productRiskLevels = riskMap
        } catch {
            // Silent fail — aging data is supplementary
            print("Failed to load aging data for products: \(error)")
            atRiskProductIds = []
            productRiskLevels = [:]
        }
    }
}

// MARK: - Expiring Products ViewModel (loads expiring product IDs from aging service)

@MainActor
class ExpiringProductsViewModel: ObservableObject {
    @Published var expiringProductIds: Set<String> = []
    @Published var expiringProducts: [ExpiringProduct] = []
    @Published var summary: ExpiringProductsSummary?
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    /// Load products with batches expiring within 90 days (or already expired)
    func loadExpiringProducts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ExpiringProductsResponse = try await apiClient.request(
                endpoint: .agingExpiring,
                queryParams: [
                    "locationId": locationId,
                    "withinDays": "90",
                    "includeExpired": "true"
                ]
            )
            
            expiringProducts = response.products
            summary = response.summary
            expiringProductIds = Set(response.products.map { $0.productId })
        } catch {
            // Silent fail — expiry data is supplementary
            print("Failed to load expiring products: \(error)")
            expiringProducts = []
            summary = nil
            expiringProductIds = []
        }
    }
}

// MARK: - Preview

#Preview {
    ProductsView()
        .environmentObject(AuthManager.shared)
}
