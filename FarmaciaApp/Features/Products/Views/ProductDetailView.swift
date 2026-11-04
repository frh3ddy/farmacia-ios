import SwiftUI
import FarmaciaKit

// MARK: - Product Detail View
// This is the unified product hub — catalog info, pricing, stock,
// inventory actions (receive/adjust), and recent activity in one place.

struct ProductDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    var onProductUpdated: ((Product) -> Void)? = nil
    
    /// Every sheet this screen opens, on one `.sheet(item:)`: two can never
    /// compete for the same presentation host, and each carries its own data
    /// (with `.sheet(isPresented:)` the content was built before a Menu
    /// action's state landed — the adjustment sheet showed the wrong type).
    @State private var sheet: DetailSheet?
    @State private var isRefreshing = false
    @State private var currentProduct: Product?
    
    
    // Product-level activity data
    @StateObject private var activityViewModel = ProductActivityViewModel()
    
    // FIFO batch / valuation data
    @StateObject private var batchViewModel = ProductBatchViewModel()
    
    // Cost & Supplier history data (from SupplierProduct + SupplierCostHistory tables)
    @StateObject private var costSupplierViewModel = CostSupplierViewModel()
    
    // Batch section expansion state
    @State private var showAllBatches = false
    
    // Cost history expansion state
    @State private var expandedSupplierHistory: String? = nil
    
    // Shared inventory view model for forms
    @StateObject private var inventoryViewModel = InventoryViewModel()
    
    // Image upload state
    @State private var isUploadingImage = false
    @State private var uploadedImageUrl: String? = nil
    @State private var showImageUploadError = false
    @State private var showImageViewer = false
    /// Camera/library → crop → preview (FarmaciaKit `PhotoFlow`, shared with
    /// Nuevo Producto); Listo uploads.
    @State private var photoFlow = PhotoFlow<UIImage>()
    @State private var pendingOriginalImage: UIImage?
    @State private var pendingLiftedImage: UIImage?
    @State private var pendingBackgroundRemoved = true
    @State private var isLiftingPhoto = false
    @State private var refreshErrorMessage: String?
    @State private var showRefreshError = false
    @State private var offlineQueue = OfflineQueueManager.shared
    @State private var storeStock: [StoreStock] = []
    @State private var storeStockLoaded = false

    private var canEditPrice: Bool {
        PriceEditing.canEdit(isOwner: authManager.isOwner, isManager: authManager.isManager, tracksInventory: displayProduct.tracksInventory)
    }

    private var displayProduct: Product {
        currentProduct ?? product
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                // Product Header (with stats row + action buttons)
                productHeader

                otherStoresCard
                
                // Price Card
                priceCard
                
                // Cost & Supplier History (not for cashiers)
                if authManager.canViewCosts {
                    costSupplierHistorySection
                }
                
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
            if canEditPrice {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            sheet = .editPrice
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
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .editPrice:
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
            case .receive:
                ReceiveInventoryFormView(
                    viewModel: inventoryViewModel,
                    product: displayProduct,
                    onComplete: {
                        Task { await refreshDependentData() }
                    }
                )
                .task {
                    // Only if the parent's initial load didn't already populate it
                    if inventoryViewModel.suppliers.isEmpty {
                        await inventoryViewModel.loadSuppliers()
                    }
                }
            case .adjust(let type):
                AdjustmentFormView(
                    adjustmentType: type,
                    viewModel: inventoryViewModel,
                    product: displayProduct,
                    onComplete: {
                        Task { await refreshDependentData() }
                    }
                )
            case .batch(let batchId):
                BatchDetailView(batchId: batchId, productName: displayProduct.displayName)
            }
        }
        .task {
            // All three loads are independent — fire in parallel.
            // Suppliers are fetched here so the receive sheet doesn't need to re-fetch.
            async let productRefresh: () = refreshProduct()
            async let suppliersLoad: () = inventoryViewModel.loadSuppliers()
            async let costSupplierLoad: () = loadCostSupplierData()
            async let storeStockLoad: () = loadStoreStock()
            _ = await (productRefresh, suppliersLoad, costSupplierLoad, storeStockLoad)
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
        VStack(spacing: DS.Spacing.m) {
            // Product Image or Placeholder
            ZStack(alignment: .bottomTrailing) {
                // Image area — tapping opens the full-screen viewer (cached +
                // downsampled). A Button, so VoiceOver can reach it; the viewer's
                // cover sits here, apart from the photo flow's.
                Group {
                    let displayUrl = uploadedImageUrl ?? displayProduct.squareImageUrl
                    if displayUrl != nil {
                        Button {
                            showImageViewer = true
                        } label: {
                            CachedProductImage(url: displayUrl, targetSize: CGSize(width: 100, height: 100)) {
                                productPlaceholder
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(.rect(cornerRadius: DS.Radius.xl))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Ver foto del producto")
                        .fullScreenCover(isPresented: $showImageViewer) {
                            if let imageUrl = uploadedImageUrl ?? displayProduct.squareImageUrl {
                                ProductImageViewer(
                                    imageUrl: imageUrl,
                                    productName: displayProduct.displayName
                                )
                            }
                        }
                    } else {
                        productPlaceholder
                    }
                }

                // Change-photo badge (owners/managers): a Menu, like Nuevo
                // Producto — no dialog to animate away before the camera opens.
                if (authManager.isOwner || authManager.isManager) && !isUploadingImage && !isLiftingPhoto {
                    Menu {
                        if CameraPicker.isAvailable {
                            Button("Tomar Foto", systemImage: "camera") {
                                photoFlow.start(.camera)
                            }
                        }
                        Button("Elegir de la Biblioteca", systemImage: "photo.on.rectangle") {
                            photoFlow.start(.library)
                        }
                    } label: {
                        Image(systemName: "camera.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Circle().fill(.tint).frame(width: 28, height: 28))
                            .frame(width: DS.minTapSize, height: DS.minTapSize)
                            .contentShape(.rect)
                    }
                    .offset(x: DS.Spacing.xs, y: DS.Spacing.xs)
                    .accessibilityLabel("Cambiar foto")
                }

                if isUploadingImage {
                    ProgressView()
                        .frame(width: 100, height: 100)
                        .background(Color.black.opacity(0.3))
                        .clipShape(.rect(cornerRadius: DS.Radius.xl))
                }
            }
            .productPhotoFlow($photoFlow, onCropped: photoCropped) {
                if let stagedImage = pendingOriginalImage {
                    ProductPhotoPreviewView(
                        liftedImage: pendingLiftedImage,
                        originalImage: stagedImage,
                        backgroundRemoved: $pendingBackgroundRemoved,
                        isLifting: isLiftingPhoto,
                        onRetake: { photoFlow.retake() },
                        onDone: {
                            let finalImage = pendingBackgroundRemoved
                                ? (pendingLiftedImage ?? stagedImage)
                                : stagedImage
                            photoFlow.cancel()
                            pendingOriginalImage = nil
                            pendingLiftedImage = nil
                            Task {
                                await uploadProductImage(finalImage)
                            }
                        }
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
            if let gtin = displayProduct.gtin, !gtin.isEmpty {
                Label(gtin, systemImage: "barcode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Código de barras \(gtin)")
            }
            
            // Stats row: STOCK | PRICE | LATEST COST
            HStack(spacing: 0) {
                // Stock
                VStack(spacing: DS.Spacing.xs) {
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
                VStack(spacing: DS.Spacing.xs) {
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
                
                // Cost: never for a cashier, even if a cached row still carries one.
                if authManager.canViewCosts {
                    Divider()
                        .frame(height: 36)
                
                    // Latest Cost (from preferred supplier or most recent cost)
                    VStack(spacing: DS.Spacing.xs) {
                        Text("COSTO")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        if costSupplierViewModel.isLoading && costSupplierViewModel.suppliers.isEmpty {
                            // The latest supplier cost is still loading: a placeholder
                            // instead of the average cost flipping to it moments later.
                            Text("$00.00")
                                .font(.title3)
                                .fontWeight(.bold)
                                .redacted(reason: .placeholder)
                                .accessibilityLabel("Cargando costo")
                        } else if let latestCost = latestSupplierCost {
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
            }
            .padding(.vertical, DS.Spacing.s)
            .background(Color(.systemGray5))
            .clipShape(.rect(cornerRadius: 10))
            
            // Action buttons (Receive + Adjust Stock)
            if authManager.canManageInventory {
                if !canAddStock {
                    Label("Este producto se vende solo en otra tienda", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: DS.Spacing.m) {
                    if canAddStock {
                        Button {
                            sheet = .receive
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
                    }

                    Menu {
                        // Static buttons — avoids SwiftUI Menu+ForEach first-item bug (FB13164795)
                        Button { selectAdjustment(.damage) } label: { Label("Daño", systemImage: "exclamationmark.triangle") }
                        Button { selectAdjustment(.expired) } label: { Label("Vencido", systemImage: "calendar.badge.exclamationmark") }
                        // Adding stock only where the product is sold; removals stay available
                        if canAddStock {
                            Button { selectAdjustment(.found) } label: { Label("Encontrado", systemImage: "magnifyingglass") }
                            Button { selectAdjustment(.returnType) } label: { Label("Devolución", systemImage: "arrow.uturn.backward") }
                        }
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
        .card()
    }
    
    /// Latest cost from the preferred supplier, or first supplier if none preferred
    private var latestSupplierCost: Double? {
        let preferred = costSupplierViewModel.suppliers.first(where: { $0.isPreferred })
        let fallback = costSupplierViewModel.suppliers.first
        return (preferred ?? fallback)?.costDouble
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(.fill.tertiary)
                .frame(width: 100, height: 100)
            
            Image(systemName: "shippingbox.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Other Stores Card

    /// The other stores' stock (tasks/other-stores-stock-epic.md). Hidden when
    /// there's none to show: offline, failed fetch, untracked, or sold only here.
    @ViewBuilder
    private var otherStoresCard: some View {
        let stores = StoreStock.others(storeStock, currentLocationId: authManager.currentLocation?.id)
        if !storeStockLoaded && expectsStoreStock {
            // First load: placeholder rows, so the card visibly fills in.
            otherStoresCardContent {
                ForEach(0..<StoreStock.placeholderRows(knownLocations: authManager.availableLocations.count), id: \.self) { _ in
                    LabeledContent("Sucursal") { Text("00 uds") }
                }
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cargando existencias")
            }
        } else if !stores.isEmpty {
            let here = displayProduct.totalInventory ?? 0
            otherStoresCardContent {
                ForEach(stores) { store in
                    let standsOut = store.standsOut(hereQuantity: here)
                    LabeledContent(store.locationName) {
                        Text("\(store.quantity) uds")
                            .fontWeight(standsOut ? .bold : .regular)
                            .foregroundStyle(standsOut ? Tone.positive.color : (store.quantity > 0 ? .primary : .secondary))
                    }
                }
            }
        }
    }

    private func otherStoresCardContent(@ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            Label("En otras tiendas", systemImage: "building.2")
                .font(.headline)

            Divider()

            rows()
        }
        .card()
    }

    // MARK: - Price Card
    
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.green)
                Text("Precios")
                    .font(.headline)
                
                Spacer()
                
                if canEditPrice {
                    Button("Editar") {
                        sheet = .editPrice
                    }
                    .font(.subheadline)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
                
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
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
            // Margin comes from cost: same rule as the COSTO column.
            if authManager.canViewCosts, let margin = displayProduct.profitMargin {
                HStack {
                    Text("Margen de Ganancia")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", margin))
                        .font(.headline)
                        .foregroundStyle(Margin.tone(forPercent: margin).color)
                }
                .padding(.top, DS.Spacing.s)
            }
        }
        .card()
    }
    
    
    private func selectAdjustment(_ type: AdjustmentType) {
        sheet = .adjust(type)
    }
    
    // MARK: - Recent Activity Section (Product-Scoped)
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
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
                VStack(spacing: DS.Spacing.s) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sin actividad aún")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
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
                            receivings: activityViewModel.receivings,
                            adjustments: activityViewModel.adjustments,
                            retryReceiving: canRetrySync ? { receiving in
                                await retrySync(.retrySquareSync(receivingId: receiving.id))
                            } : nil,
                            retryAdjustment: canRetrySync ? { adjustment in
                                await retrySync(.retryAdjustmentSquareSync(adjustmentId: adjustment.id))
                            } : nil
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
        .card()
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
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
        .padding(.vertical, DS.Spacing.xxs)
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.purple)
                Text("Detalles")
                    .font(.headline)
            }
            
            Divider()
            
            if let description = displayProduct.squareDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
        .card()
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
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
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
                        .foregroundStyle(Tone.positive.color)
                    VStack(alignment: .leading) {
                        Text("Sincronizado con Square")
                            .font(.subheadline)
                        Text("El producto es visible en Square POS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tone.caution.color)
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
        .card()
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
        async let storeStockLoad: () = loadStoreStock()
        _ = await (productRefresh, activityLoad, batchLoad, costSupplierLoad, storeStockLoad)
    }

    private var expectsStoreStock: Bool {
        StoreStock.isExpected(tracksInventory: displayProduct.tracksInventory,
                              soldOnlyAtLocationId: displayProduct.soldOnlyAtLocationId)
    }

    private func loadStoreStock() async {
        guard expectsStoreStock else { return }
        storeStock = await APIClient.shared.storeStock(productId: product.id)
        storeStockLoaded = true
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
        } catch NetworkError.cancelled {
            // A newer refresh (or the view going away) superseded this one —
            // not a real failure, nothing to show the user.
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

    /// Receiving and found/return adjustments only where the product is sold (the API refuses the rest).
    private var canAddStock: Bool {
        StockEntry.canAdd(soldOnlyAtLocationId: displayProduct.soldOnlyAtLocationId,
                          currentLocationId: authManager.currentLocation?.id)
    }

    private var canRetrySync: Bool {
        SquareSync.canRetry(isOwner: authManager.isOwner)
    }

    /// Retries one record's Square sync, then reloads the activity so its warning clears.
    private func retrySync(_ endpoint: APIEndpoint) async -> String {
        let message = await SquareSyncRetry.run(endpoint)
        await loadActivity()
        return message
    }
    
    private func loadCostSupplierData() async {
        // Every caller (first load, refresh after a write) goes through here: the API refuses cashiers
        guard authManager.canViewCosts else { return }
        await costSupplierViewModel.loadData(productId: displayProduct.id)
    }
    
    private func loadBatchData() async {
        // Same rule as the section: owners and managers (refresh after a write called it for everyone)
        guard authManager.isOwner || authManager.isManager,
              let locationId = authManager.currentLocation?.id else { return }
        await batchViewModel.loadBatches(
            productId: displayProduct.id,
            locationId: locationId
        )
    }
    
    /// The square photo, as the flow moves on to the preview: background
    /// removal runs while it's on screen (the preview shows a spinner), and
    /// Listo uploads the chosen version.
    private func photoCropped(_ image: UIImage) {
        pendingOriginalImage = image
        pendingLiftedImage = nil
        pendingBackgroundRemoved = true
        Task {
            isLiftingPhoto = true
            let lifted = await SubjectLifter.liftSubject(from: image)
            // Reference-identical result means lifting had no effect (no
            // clear subject, or it failed) — leave the toggle hidden.
            if lifted !== image {
                pendingLiftedImage = lifted
            }
            isLiftingPhoto = false
        }
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
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
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
                    Text("\(batchViewModel.batches.count) lote\(batchViewModel.batches.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            if batchViewModel.batches.isEmpty && !batchViewModel.isLoading {
                VStack(spacing: DS.Spacing.s) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sin lotes de inventario")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
            } else {
                // Aging risk summary (from aging service)
                if let aging = batchViewModel.productAging {
                    agingRiskSummaryCard(aging)
                }
                
                // Batch summary bar
                if let agingInfo = batchViewModel.lotSummary {
                    HStack(spacing: DS.Spacing.m) {
                        agingPill(label: "0–30d", count: agingInfo.fresh, color: BatchAge.tone(days: 0).color)
                        agingPill(label: "31–90d", count: agingInfo.moderate, color: BatchAge.tone(days: 31).color)
                        agingPill(label: "90+d", count: agingInfo.old, color: BatchAge.tone(days: 91).color)
                    }
                }
                
                // Expiry summary (if any batches have expiry dates)
                let expiredCount = batchViewModel.lotSummary?.expired ?? 0
                let expiringSoonCount = batchViewModel.lotSummary?.expiringSoon ?? 0
                if expiredCount > 0 || expiringSoonCount > 0 {
                    HStack(spacing: DS.Spacing.m) {
                        if expiredCount > 0 {
                            StatusLabel("\(expiredCount) vencido\(expiredCount == 1 ? "" : "s")", tone: .critical)
                        }
                        if expiringSoonCount > 0 {
                            StatusLabel("\(expiringSoonCount) por vencer", tone: .caution)
                        }
                        Spacer()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, DS.Spacing.xs)
                }
                
                // Lots in the order FIFO sells them (first 3 = next to sell, expand for all)
                let sortedBatches = BatchValuation.fifoOrder(batchViewModel.batches)
                let nextOutId = BatchValuation.nextOut(batchViewModel.batches)?.id
                let batchesToShow = showAllBatches ? sortedBatches : Array(sortedBatches.prefix(3))
                ForEach(batchesToShow) { batch in
                    Button {
                        sheet = .batch(batch.batchId)
                    } label: {
                        batchRow(batch, isNextOut: batch.id == nextOutId)
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
                        .frame(minHeight: DS.minTapSize)
                        .contentShape(.rect)
                    }
                }
            }
        }
        .card()
    }
    
    @ViewBuilder
    private func agingRiskSummaryCard(_ aging: ProductAgingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            // Risk level + cash tied up
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: aging.riskLevel.icon)
                        .font(.caption)
                    Text("Riesgo \(aging.riskLevel.displayName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(aging.riskLevel.color)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(aging.formattedCashTiedUp)
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("inmovilizado")
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
                HStack(spacing: DS.Spacing.s) {
                    ForEach(aging.bucketDistribution) { bucket in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(bucketColor(bucket.bucket.min))
                                .frame(width: 6, height: 6)
                            Text(bucket.bucket.label)
                                .font(.caption2)
                            Text("\(bucket.unitCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            
            // Cash at risk callout (if any >90d inventory)
            let atRiskCash = batchViewModel.cashAtRisk
            if atRiskCash > 0 {
                StatusLabel(String(format: "$%.2f en riesgo (más de 90 días)", atRiskCash), tone: .critical)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, DS.Spacing.s)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(Tone.critical.color.opacity(0.08), in: .rect(cornerRadius: DS.Radius.m))
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
    
    /// The aging service's buckets start at 0/31/61/91 days; color them like the lot age dots.
    private func bucketColor(_ minDays: Int) -> Color {
        BatchAge.tone(days: minDays).color
    }
    
    private func agingPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: DS.Radius.m))
    }
    
    private func batchRow(_ batch: BatchValuation, isNextOut: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Quantity, unit cost, and value
            HStack(spacing: 10) {
                // Age indicator (or expiry warning)
                if let tone = batch.expiryTone, tone != .neutral {
                    // The pill below says it in words ("Vencido …" / "Vence …").
                    Image(systemName: tone.systemImage)
                        .font(.caption2)
                        .foregroundStyle(tone.color)
                } else {
                    Circle()
                        .fill(batchAgeColor(batch.age))
                        .frame(width: 10, height: 10)
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(batch.quantity) uds")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(ReportFormat.currency(batch.unitCost)) c/u")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isNextOut {
                            ToneBadge("Sale siguiente", tone: .info)
                        }
                    }
                    
                    // Row 2: Age + received date + source
                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(batch.age) días")
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
                Text(ReportFormat.currency(batch.value))
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
                                    .font(.caption2)
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
        .padding(.vertical, DS.Spacing.xs)
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
        
        if let expiry = batch.expiryDate, let tone = batch.expiryTone {
            let formatted = Expiry.display(expiry)
            let label = tone == .critical ? "Vencido \(formatted)" : "Vence \(formatted)"
            pills.append(BatchPill(icon: tone.systemImage, label: label, color: tone.color))
        }
        
        if let invoice = batch.invoiceNumber, !invoice.isEmpty {
            pills.append(BatchPill(icon: "doc.text", label: invoice, color: .gray))
        }
        
        return pills
    }
    
    private func batchAgeColor(_ age: Int) -> Color {
        BatchAge.tone(days: age).color
    }
    
    // MARK: - Cost & Supplier History Section
    
    private var costSupplierHistorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.cyan)
                Text("Historial de Costos y Proveedores")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Refresh only: the first load shows skeleton rows below.
                if costSupplierViewModel.isLoading && !costSupplierViewModel.suppliers.isEmpty {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Divider()
            
            if costSupplierViewModel.isLoading && costSupplierViewModel.suppliers.isEmpty {
                // Skeleton in the shape of a supplier row.
                HStack(spacing: DS.Spacing.m) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Nombre del proveedor")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Notas")
                            .font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text("$00.00")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("per ud")
                            .font(.caption2)
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cargando datos de proveedor")
            } else if costSupplierViewModel.suppliers.isEmpty && costSupplierViewModel.costHistory.isEmpty {
                VStack(spacing: DS.Spacing.s) {
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
                .padding(.vertical, DS.Spacing.m)
            } else {
                // Current Suppliers section (from SupplierProduct)
                if !costSupplierViewModel.suppliers.isEmpty {
                    Text("Proveedores Actuales")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(costSupplierViewModel.suppliers) { supplier in
                        HStack(spacing: DS.Spacing.m) {
                            // Supplier icon
                            ZStack {
                                Circle()
                                    .fill(supplier.isPreferred ? Color.blue.opacity(0.15) : Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                Image(systemName: supplier.isPreferred ? "star.fill" : "building.2")
                                    .font(.caption)
                                    .foregroundStyle(supplier.isPreferred ? Color.blue : Color.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                HStack(spacing: DS.Spacing.xs) {
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
                                            .clipShape(.rect(cornerRadius: DS.Radius.s))
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
                            
                            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                                Text(supplier.formattedCost)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("per ud")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
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
                                        HStack(spacing: DS.Spacing.xxs) {
                                            Image(systemName: trend.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.caption2)
                                            Text(String(format: "%.1f%%", abs(trend.percent)))
                                                .font(.caption2)
                                        }
                                        .foregroundStyle((trend.change > 0 ? Tone.critical : Tone.positive).color)
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
                                    HStack(spacing: DS.Spacing.s) {
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
                                    .padding(.leading, DS.Spacing.l)
                                }
                                
                                if group.costHistory.count > 10 {
                                    Text("+ \(group.costHistory.count - 10) more entries")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, DS.Spacing.l)
                                }
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                        
                        if group.supplierId != costSupplierViewModel.costHistory.last?.supplierId {
                            Divider()
                        }
                    }
                }
            }
        }
        .card()
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
            hasSquareSync: true,
            tracksInventory: true
        ))
        .environmentObject(AuthManager.shared)
    }
}

// MARK: - Detail Sheet

/// What `ProductDetailView`'s single sheet shows.
private enum DetailSheet: Identifiable {
    case editPrice
    case receive
    case adjust(AdjustmentType)
    case batch(String)

    var id: String {
        switch self {
        case .editPrice: "editPrice"
        case .receive: "receive"
        case .adjust(let type): "adjust-\(type.id)"
        case .batch(let batchId): "batch-\(batchId)"
        }
    }
}
