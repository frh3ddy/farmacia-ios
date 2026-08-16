import SwiftUI

// MARK: - Product Detail View
// This is the unified product hub — catalog info, pricing, stock,
// inventory actions (receive/adjust), and recent activity in one place.

struct ProductDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    var onProductUpdated: ((Product) -> Void)? = nil
    
    @State private var showEditPrice = false
    @State private var isRefreshing = false
    @State private var currentProduct: Product?
    
    // Inventory action sheets
    @State private var showReceiveSheet = false
    // Item-driven sheet presentation: with .sheet(isPresented:) the content
    // closure is built BEFORE the state update from the Menu action
    // propagates, so the first presentation always showed the default type
    // (.damage) regardless of the tapped item. .sheet(item:) evaluates the
    // content after the item is set — the selected type is always correct.
    @State private var adjustmentSheetType: AdjustmentType?
    
    // Product-level activity data
    @StateObject private var activityViewModel = ProductActivityViewModel()
    
    // FIFO batch / valuation data
    @StateObject private var batchViewModel = ProductBatchViewModel()
    
    // Cost & Supplier history data (from SupplierProduct + SupplierCostHistory tables)
    @StateObject private var costSupplierViewModel = CostSupplierViewModel()
    
    // Batch section expansion state
    @State private var showAllBatches = false
    @State private var selectedBatchId: String? = nil
    
    // Cost history expansion state
    @State private var expandedSupplierHistory: String? = nil
    
    // Shared inventory view model for forms
    @StateObject private var inventoryViewModel = InventoryViewModel()
    
    // Image upload state
    @State private var showImageSourcePicker = false
    @State private var isUploadingImage = false
    @State private var uploadedImageUrl: String? = nil
    @State private var showImageUploadError = false
    @State private var showImageViewer = false
    @State private var refreshErrorMessage: String?
    @State private var showRefreshError = false
    @State private var offlineQueue = OfflineQueueManager.shared

    private var displayProduct: Product {
        currentProduct ?? product
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Product Header (with stats row + action buttons)
                productHeader
                
                // Price Card
                priceCard
                
                // Cost & Supplier History
                costSupplierHistorySection
                
                // FIFO Batch Breakdown
                if authManager.isOwner || authManager.isManager {
                    fifoBatchSection
                }
                
                // Recent Activity (product-scoped)
                recentActivitySection
                
                // Details Card
                detailsCard
                
                // Square Sync Status
                squareSyncCard
            }
            .padding()
        }
        .navigationTitle("Detalle de Producto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authManager.isOwner || authManager.isManager {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditPrice = true
                        } label: {
                            Label("Editar Precio", systemImage: "dollarsign.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Más opciones")
                }
            }
        }
        .sheet(isPresented: $showEditPrice) {
            EditPriceView(product: displayProduct) { updatedProduct in
                currentProduct = updatedProduct
                // Propagate the new price to the products list + SwiftData cache
                onProductUpdated?(updatedProduct)
                // Follow with a fresh GET — the server is the source of truth
                // and the PATCH response may not carry every derived field
                Task {
                    await refreshProduct()
                }
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView(
                viewModel: inventoryViewModel,
                preSelectedProduct: displayProduct,
                onComplete: {
                    Task { await refreshDependentData() }
                }
            )
            .task {
                // Load form data only when sheet opens — and only if the
                // parent's initial load didn't already populate it
                if inventoryViewModel.products.isEmpty {
                    await inventoryViewModel.loadProducts()
                }
                if inventoryViewModel.suppliers.isEmpty {
                    await inventoryViewModel.loadSuppliers()
                }
            }
        }
        .sheet(item: $adjustmentSheetType) { type in
            AdjustmentFormView(
                adjustmentType: type,
                viewModel: inventoryViewModel,
                preSelectedProduct: displayProduct,
                onComplete: {
                    Task { await refreshDependentData() }
                }
            )
            .task {
                // Load form data only when sheet opens — skip if already loaded
                if inventoryViewModel.products.isEmpty {
                    await inventoryViewModel.loadProducts()
                }
                if inventoryViewModel.suppliers.isEmpty {
                    await inventoryViewModel.loadSuppliers()
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedBatchId != nil },
            set: { if !$0 { selectedBatchId = nil } }
        )) {
            if let batchId = selectedBatchId {
                BatchDetailView(batchId: batchId, productName: displayProduct.displayName)
            }
        }
        .task {
            // All four loads are independent — fire in parallel.
            // The form data (products list + suppliers) is fetched here so the
            // receive/adjustment sheets don't need to re-fetch when they open.
            async let productRefresh: () = refreshProduct()
            async let productsLoad: () = inventoryViewModel.loadProducts()
            async let suppliersLoad: () = inventoryViewModel.loadSuppliers()
            async let costSupplierLoad: () = loadCostSupplierData()
            _ = await (productRefresh, productsLoad, suppliersLoad, costSupplierLoad)
        }
        .task(id: "fifo-batches") {
            // Lazy: load FIFO batches only for owners/managers
            if authManager.isOwner || authManager.isManager {
                await loadBatchData()
            }
        }
        .task(id: "activity") {
            // Lazy: load activity history after main data
            await loadActivity()
        }
        .refreshable {
            await refreshDependentData()
        }
        .onChange(of: offlineQueue.pendingCount) { oldValue, newValue in
            // A queued write for this product may have just synced (or been
            // moved to failedRequests) — re-fetch so the screen can't keep
            // showing pre-edit numbers after the edit actually landed.
            if newValue < oldValue {
                Task { await refreshDependentData() }
            }
        }
        .alert("Error", isPresented: $inventoryViewModel.showError) {
            Button("OK") {}
        } message: {
            Text(inventoryViewModel.errorMessage ?? "Ocurrió un error")
        }
        .alert("Éxito", isPresented: $inventoryViewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(inventoryViewModel.successMessage ?? "Operación completada")
        }
        .alert("Error al Subir Imagen", isPresented: $showImageUploadError) {
            Button("OK") {}
        } message: {
            Text("No se pudo subir la imagen del producto. Intenta de nuevo.")
        }
        .alert("Error al Actualizar", isPresented: $showRefreshError) {
            Button("OK") {}
        } message: {
            Text(refreshErrorMessage ?? "No se pudieron cargar los datos más recientes del producto.")
        }
    }
    
    // MARK: - Product Header
    
    private var productHeader: some View {
        VStack(spacing: 12) {
            // Product Image or Placeholder
            ZStack(alignment: .bottomTrailing) {
                // Image area — tapping opens full-screen viewer (cached + downsampled)
                Group {
                    let displayUrl = uploadedImageUrl ?? displayProduct.squareImageUrl
                    if displayUrl != nil {
                        CachedProductImage(url: displayUrl, targetSize: CGSize(width: 100, height: 100)) {
                            productPlaceholder
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(.rect(cornerRadius: 16))
                        .onTapGesture {
                            showImageViewer = true
                        }
                    } else {
                        productPlaceholder
                    }
                }
                
                // Camera icon overlay — tapping opens upload picker (owners/managers only)
                if (authManager.isOwner || authManager.isManager) && !isUploadingImage {
                    Button {
                        showImageSourcePicker = true
                    } label: {
                        Image(systemName: "camera.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.blue).frame(width: 28, height: 28))
                    }
                    .offset(x: 4, y: 4)
                    .accessibilityLabel("Cambiar foto")
                }

                if isUploadingImage {
                    ProgressView()
                        .frame(width: 100, height: 100)
                        .background(Color.black.opacity(0.3))
                        .clipShape(.rect(cornerRadius: 16))
                }
            }
            .confirmationDialog("Cambiar Imagen del Producto", isPresented: $showImageSourcePicker) {
                Button("Tomar Foto") {
                    ImagePickerPresenter.present(sourceType: .camera) { image in
                        Task {
                            await uploadProductImage(image)
                        }
                    }
                }
                Button("Elegir de la Biblioteca") {
                    ImagePickerPresenter.present(sourceType: .photoLibrary) { image in
                        Task {
                            await uploadProductImage(image)
                        }
                    }
                }
                Button("Cancelar", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                if let imageUrl = uploadedImageUrl ?? displayProduct.squareImageUrl {
                    ProductImageViewer(
                        imageUrl: imageUrl,
                        productName: displayProduct.displayName
                    )
                }
            }
            
            // Product Name
            Text(displayProduct.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // SKU
            if let sku = displayProduct.sku {
                Text("SKU: \(sku)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Stats row: STOCK | PRICE | LATEST COST
            HStack(spacing: 0) {
                // Stock
                VStack(spacing: 4) {
                    Text("EXISTENCIA")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text("\(displayProduct.totalInventory ?? 0)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 36)
                
                // Price
                VStack(spacing: 4) {
                    Text("PRECIO")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    if let price = displayProduct.sellingPrice {
                        Text(String(format: "$%.2f", price))
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("—")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 36)
                
                // Latest Cost (from preferred supplier or most recent cost)
                VStack(spacing: 4) {
                    Text("COSTO")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    if let latestCost = latestSupplierCost {
                        Text(String(format: "$%.2f", latestCost))
                            .font(.title3)
                            .fontWeight(.bold)
                    } else if let avgCost = displayProduct.averageCost {
                        Text(String(format: "$%.2f", avgCost))
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("—")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .clipShape(.rect(cornerRadius: 10))
            
            // Action buttons (Receive + Adjust Stock)
            if authManager.canManageInventory {
                HStack(spacing: 12) {
                    Button {
                        showReceiveSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline)
                            Text("Recibir Inventario")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    
                    Menu {
                        // Static buttons — avoids SwiftUI Menu+ForEach first-item bug (FB13164795)
                        Button { selectAdjustment(.damage) } label: { Label("Daño", systemImage: "exclamationmark.triangle") }
                        Button { selectAdjustment(.expired) } label: { Label("Vencido", systemImage: "calendar.badge.exclamationmark") }
                        Button { selectAdjustment(.found) } label: { Label("Encontrado", systemImage: "magnifyingglass") }
                        Button { selectAdjustment(.returnType) } label: { Label("Devolución", systemImage: "arrow.uturn.backward") }
                        Button { selectAdjustment(.countCorrection) } label: { Label("Corrección de Conteo", systemImage: "number") }
                        Button { selectAdjustment(.theft) } label: { Label("Robo", systemImage: "lock.slash") }
                        Button { selectAdjustment(.writeOff) } label: { Label("Baja", systemImage: "xmark.circle") }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                            Text("Ajustar Inventario")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    /// Latest cost from the preferred supplier, or first supplier if none preferred
    private var latestSupplierCost: Double? {
        let preferred = costSupplierViewModel.suppliers.first(where: { $0.isPreferred })
        let fallback = costSupplierViewModel.suppliers.first
        return (preferred ?? fallback)?.costDouble
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .frame(width: 100, height: 100)
            
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Price Card
    
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.green)
                Text("Precios")
                    .font(.headline)
                
                Spacer()
                
                if authManager.isOwner || authManager.isManager {
                    Button("Editar") {
                        showEditPrice = true
                    }
                    .font(.subheadline)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Precio de Venta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let price = displayProduct.formattedPrice {
                        Text(price)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    } else {
                        Text("No definido")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Costo Prom.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let cost = displayProduct.formattedCost {
                        Text(cost)
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("N/A")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Margin
            if let margin = displayProduct.profitMargin {
                HStack {
                    Text("Margen de Ganancia")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", margin))
                        .font(.headline)
                        .foregroundStyle(margin >= 20 ? .green : (margin >= 10 ? .orange : .red))
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    
    private func selectAdjustment(_ type: AdjustmentType) {
        adjustmentSheetType = type
    }
    
    // MARK: - Recent Activity Section (Product-Scoped)
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.indigo)
                Text("Actividad Reciente")
                    .font(.headline)
                
                Spacer()
                
                if activityViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider()
            
            if activityViewModel.combinedActivity.isEmpty && !activityViewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sin actividad aún")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // Show combined and chronologically sorted activity
                ForEach(activityViewModel.combinedActivity.prefix(5)) { item in
                    activityRow(item)
                    
                    if item.id != activityViewModel.combinedActivity.prefix(5).last?.id {
                        Divider()
                    }
                }
                
                // Show all link if more than 5
                if activityViewModel.combinedActivity.count > 5 {
                    NavigationLink {
                        ProductActivityFullView(
                            product: displayProduct,
                            recepciones: activityViewModel.recepciones,
                            ajustes: activityViewModel.ajustes
                        )
                    } label: {
                        HStack {
                            Text("Ver Toda la Actividad")
                                .font(.subheadline)
                            Spacer()
                            Text("\(activityViewModel.combinedActivity.count) total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func activityRow(_ item: ProductActivityItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundStyle(item.iconColor)
                .frame(width: 28, height: 28)
                .background(item.iconColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))
            
            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Quantity change
            Text(item.quantityDisplay)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(item.quantityColor)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.purple)
                Text("Detalles")
                    .font(.headline)
            }
            
            Divider()
            
            if let description = displayProduct.squareDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Descripción")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(description)
                        .font(.subheadline)
                }
            }
            
            if let category = displayProduct.category {
                detailRow(title: "Categoría", value: category.name)
            }
            
            if let createdAt = displayProduct.createdAt {
                detailRow(title: "Creado", value: createdAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
    
    // MARK: - Square Sync Card
    
    private var squareSyncCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.orange)
                Text("Sincronización Square")
                    .font(.headline)
            }
            
            Divider()
            
            HStack {
                if displayProduct.hasSquareSync == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Sincronizado con Square")
                            .font(.subheadline)
                        Text("El producto es visible en Square POS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Solo Local")
                            .font(.subheadline)
                        Text("El producto no está sincronizado con Square POS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let syncedAt = displayProduct.squareDataSyncedAt {
                Text("Última sinc: \(syncedAt.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    // MARK: - Actions

    /// Product detail + everything derived from it (activity, FIFO batches,
    /// cost/supplier history) — the bundle every write on this screen needs
    /// refreshed afterward, whether that write just completed live or was a
    /// queued offline edit that synced since the screen last loaded.
    private func refreshDependentData() async {
        async let productRefresh: () = refreshProduct()
        async let activityLoad: () = loadActivity()
        async let batchLoad: () = loadBatchData()
        async let costSupplierLoad: () = loadCostSupplierData()
        _ = await (productRefresh, activityLoad, batchLoad, costSupplierLoad)
    }

    private func refreshProduct() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        isRefreshing = true
        
        do {
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .getProduct(id: product.id),
                queryParams: ["locationId": locationId]
            )
            currentProduct = response.data
            onProductUpdated?(response.data)
            // Write-through: update cache with fresh product data
            ProductCacheManager.shared.saveProduct(response.data)
        } catch let error as NetworkError {
            refreshErrorMessage = error.errorDescription
            showRefreshError = true
        } catch {
            refreshErrorMessage = "No se pudieron cargar los datos más recientes del producto."
            showRefreshError = true
        }
        
        isRefreshing = false
    }
    
    private func loadActivity() async {
        await activityViewModel.loadActivity(productId: displayProduct.id)
    }
    
    private func loadCostSupplierData() async {
        await costSupplierViewModel.loadData(productId: displayProduct.id)
    }
    
    private func loadBatchData() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await batchViewModel.loadBatches(
            productId: displayProduct.id,
            locationId: locationId
        )
    }
    
    private func uploadProductImage(_ image: UIImage) async {
        // Resize to upload ceiling (1600px longest edge) + compress to JPEG.
        // Camera photos are 12+ MP — uploading them raw produces multi-MB payloads.
        guard let imageData = image.jpegDataForUpload() else { return }
        
        isUploadingImage = true
        defer { isUploadingImage = false }
        
        do {
            let response: ImageUploadResponse = try await APIClient.shared.uploadImage(
                endpoint: .uploadProductImage(id: displayProduct.id),
                imageData: imageData,
                filename: "product_\(displayProduct.id).jpg"
            )
            if let url = response.imageUrl {
                // Invalidate caches so the fresh image is fetched even if
                // the backend reused the same URL
                if let oldUrl = URL(string: uploadedImageUrl ?? displayProduct.squareImageUrl ?? "") {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: oldUrl))
                }
                if let newUrl = URL(string: url) {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: newUrl))
                }
                ProductImageCache.shared.invalidate(url: url)
                uploadedImageUrl = url
                // Pull the fresh product (with the new image URL) and
                // propagate it to the products list + SwiftData cache
                // via onProductUpdated inside refreshProduct()
                await refreshProduct()
            }
        } catch {
            print("Failed to upload product image: \(error)")
            showImageUploadError = true
        }
    }
    
    // MARK: - FIFO Batch Breakdown Section
    
    private var fifoBatchSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(.teal)
                Text("Lotes FIFO")
                    .font(.headline)
                
                Spacer()
                
                if batchViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !batchViewModel.batches.isEmpty {
                    Text("\(batchViewModel.batches.count) batch\(batchViewModel.batches.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            if batchViewModel.batches.isEmpty && !batchViewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sin lotes de inventario")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // Aging risk summary (from aging service)
                if let aging = batchViewModel.productAging {
                    agingRiskSummaryCard(aging)
                }
                
                // Batch summary bar
                if let agingInfo = batchViewModel.agingSummary {
                    HStack(spacing: 12) {
                        agingPill(label: "<30d", count: agingInfo.fresh, color: .green)
                        agingPill(label: "30-90d", count: agingInfo.moderate, color: .orange)
                        agingPill(label: ">90d", count: agingInfo.old, color: .red)
                    }
                }
                
                // Expiry summary (if any batches have expiry dates)
                let expiredCount = batchViewModel.batches.filter { $0.isExpired }.count
                let expiringSoonCount = batchViewModel.batches.filter { !$0.isExpired && $0.expiresWithin(days: 90) }.count
                if expiredCount > 0 || expiringSoonCount > 0 {
                    HStack(spacing: 12) {
                        if expiredCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("\(expiredCount) expired")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.red)
                        }
                        if expiringSoonCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.caption2)
                                Text("\(expiringSoonCount) expiring soon")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.orange)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Individual batches (newest first, show first 3, expand for all)
                let sortedBatches = batchViewModel.batches.sorted { $0.receivedAt > $1.receivedAt }
                let batchesToShow = showAllBatches ? sortedBatches : Array(sortedBatches.prefix(3))
                ForEach(batchesToShow) { batch in
                    Button {
                        selectedBatchId = batch.batchId
                    } label: {
                        batchRow(batch)
                    }
                    .buttonStyle(.plain)
                    if batch.id != batchesToShow.last?.id {
                        Divider()
                    }
                }
                
                // Show more / less toggle
                if batchViewModel.batches.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllBatches.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showAllBatches ? "Ver Menos" : "Ver Todos")
                            Image(systemName: showAllBatches ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func agingRiskSummaryCard(_ aging: ProductAgingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Risk level + cash tied up
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: aging.riskLevel.icon)
                        .font(.caption)
                    Text("\(aging.riskLevel.displayName) Risk")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(aging.riskLevel.color)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(aging.formattedCashTiedUp)
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("tied up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Bucket distribution bar (visual)
            if !aging.bucketDistribution.isEmpty {
                GeometryReader { geometry in
                    HStack(spacing: 1) {
                        ForEach(aging.bucketDistribution) { bucket in
                            let width = max(2, geometry.size.width * CGFloat(bucket.percentageOfTotal / 100))
                            Rectangle()
                                .fill(bucketColor(bucket.bucket.min))
                                .frame(width: width, height: 6)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 3))
                }
                .frame(height: 6)
                
                // Bucket legend
                HStack(spacing: 8) {
                    ForEach(aging.bucketDistribution) { bucket in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(bucketColor(bucket.bucket.min))
                                .frame(width: 6, height: 6)
                            Text(bucket.bucket.label)
                                .font(.system(size: 9))
                            Text("\(bucket.unitCount)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            
            // Cash at risk callout (if any >90d inventory)
            let atRiskCash = batchViewModel.cashAtRisk
            if atRiskCash > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(String(format: "$%.2f at risk (>90 days)", atRiskCash))
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.08))
                .clipShape(.rect(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(aging.riskLevel.color.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(aging.riskLevel.color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func bucketColor(_ minDays: Int) -> Color {
        if minDays >= 91 { return .red }
        if minDays >= 61 { return .orange }
        if minDays >= 31 { return .yellow }
        return .green
    }
    
    private func agingPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }
    
    private func batchRow(_ batch: BatchValuation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Quantity, unit cost, and value
            HStack(spacing: 10) {
                // Age indicator (or expiry warning)
                if batch.isExpired {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if batch.expiresWithin(days: 90) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Circle()
                        .fill(batchAgeColor(batch.age))
                        .frame(width: 10, height: 10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(batch.quantity) uds")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("@ $\(batch.unitCost)/ea")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Row 2: Age + received date + source
                    HStack(spacing: 4) {
                        Text("\(batch.age)d old")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\u{2022}")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(batch.receivedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if batch.source != nil {
                            Text("\u{2022}")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(batch.sourceLabel)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Batch value
                Text("$\(batch.value)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            
            // Row 3: Batch metadata pills (lot#, supplier, expiry)
            let pills = batchMetadataPills(batch)
            if !pills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pills, id: \.label) { pill in
                            HStack(spacing: 3) {
                                Image(systemName: pill.icon)
                                    .font(.system(size: 9))
                                Text(pill.label)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(pill.color.opacity(0.12))
                            .foregroundStyle(pill.color)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private struct BatchPill: Hashable {
        let icon: String
        let label: String
        let color: Color
    }
    
    private func batchMetadataPills(_ batch: BatchValuation) -> [BatchPill] {
        var pills: [BatchPill] = []
        
        if let lot = batch.batchNumber, !lot.isEmpty {
            pills.append(BatchPill(icon: "number", label: lot, color: .purple))
        }
        
        if let supplier = batch.supplierName, !supplier.isEmpty {
            pills.append(BatchPill(icon: "building.2", label: supplier, color: .blue))
        }
        
        if let expiry = batch.expiryDate {
            let formatted = expiry.formatted(date: .abbreviated, time: .omitted)
            if batch.isExpired {
                pills.append(BatchPill(icon: "xmark.circle", label: "Vencido \(formatted)", color: .red))
            } else if batch.expiresWithin(days: 90) {
                pills.append(BatchPill(icon: "clock", label: "Vence \(formatted)", color: .orange))
            } else {
                pills.append(BatchPill(icon: "calendar", label: "Vence \(formatted)", color: .green))
            }
        }
        
        if let invoice = batch.invoiceNumber, !invoice.isEmpty {
            pills.append(BatchPill(icon: "doc.text", label: invoice, color: .gray))
        }
        
        return pills
    }
    
    private func batchAgeColor(_ age: Int) -> Color {
        if age < 30 { return .green }
        if age < 90 { return .orange }
        return .red
    }
    
    // MARK: - Cost & Supplier History Section
    
    private var costSupplierHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.cyan)
                Text("Historial de Costos y Proveedores")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if costSupplierViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Divider()
            
            if costSupplierViewModel.isLoading && costSupplierViewModel.suppliers.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Cargando datos de proveedor...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if costSupplierViewModel.suppliers.isEmpty && costSupplierViewModel.costHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sin datos de proveedor aún")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Los costos de proveedores aparecerán aquí cuando se reciban productos de proveedores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // Current Suppliers section (from SupplierProduct)
                if !costSupplierViewModel.suppliers.isEmpty {
                    Text("Proveedores Actuales")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(costSupplierViewModel.suppliers) { supplier in
                        HStack(spacing: 12) {
                            // Supplier icon
                            ZStack {
                                Circle()
                                    .fill(supplier.isPreferred ? Color.blue.opacity(0.15) : Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                Image(systemName: supplier.isPreferred ? "star.fill" : "building.2")
                                    .font(.caption)
                                    .foregroundStyle(supplier.isPreferred ? Color.blue : Color.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(supplier.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if supplier.isPreferred {
                                        Text("Preferido")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(.rect(cornerRadius: 4))
                                    }
                                }
                                if let notes = supplier.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(supplier.formattedCost)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("per ud")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Cost History section (from SupplierCostHistory)
                if !costSupplierViewModel.costHistory.isEmpty {
                    if !costSupplierViewModel.suppliers.isEmpty {
                        Divider()
                    }
                    
                    Text("Historial de Costos por Proveedor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(costSupplierViewModel.costHistory) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            // Supplier header with trend
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedSupplierHistory == group.supplierId {
                                        expandedSupplierHistory = nil
                                    } else {
                                        expandedSupplierHistory = group.supplierId
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(group.supplierName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    
                                    if let current = group.currentCost {
                                        Text(current.formattedCost)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    // Cost trend indicator
                                    if let trend = group.costTrend {
                                        HStack(spacing: 2) {
                                            Image(systemName: trend.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.caption2)
                                            Text(String(format: "%.1f%%", abs(trend.percent)))
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(trend.change > 0 ? .red : .green)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(group.costHistory.count) entries")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    Image(systemName: expandedSupplierHistory == group.supplierId ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Expanded cost timeline
                            if expandedSupplierHistory == group.supplierId {
                                ForEach(group.costHistory.prefix(10)) { entry in
                                    HStack(spacing: 8) {
                                        // Timeline dot
                                        Circle()
                                            .fill(entry.isCurrent ? Color.blue : Color(.systemGray4))
                                            .frame(width: 6, height: 6)
                                        
                                        Text(entry.effectiveAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .leading)
                                        
                                        Text(entry.formattedCost)
                                            .font(.caption)
                                            .fontWeight(entry.isCurrent ? .semibold : .regular)
                                        
                                        Spacer()
                                        
                                        Text(entry.sourceLabel)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        if entry.isCurrent {
                                            Text("Actual")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundStyle(.blue)
                                                .clipShape(.rect(cornerRadius: 3))
                                        }
                                    }
                                    .padding(.leading, 16)
                                }
                                
                                if group.costHistory.count > 10 {
                                    Text("+ \(group.costHistory.count - 10) more entries")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        if group.supplierId != costSupplierViewModel.costHistory.last?.supplierId {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Product Detail Response

struct ProductDetailResponse: Decodable {
    let success: Bool
    let data: Product
}


// MARK: - Preview

#Preview {
    NavigationStack {
        ProductDetailView(product: Product(
            id: "1",
            name: "Paracetamol 500mg",
            sku: "PARA-500",
            categoryId: nil,
            squareProductName: "Paracetamol 500mg",
            squareDescription: "Pain reliever and fever reducer",
            squareImageUrl: nil,
            squareVariationName: "Regular",
            squareDataSyncedAt: Date(),
            category: nil,
            supplierCount: 2,
            createdAt: Date(),
            sellingPrice: 45.00,
            currency: "MXN",
            totalInventory: 150,
            averageCost: 30.00,
            hasSquareSync: true
        ))
        .environmentObject(AuthManager.shared)
    }
}
