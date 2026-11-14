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
            VStack(spacing: DS.Spacing.m) {
                // Identity + price, cost, margin and where the cost comes from
                headerCard

                if displayProduct.tracksInventory != false {
                    ProductInventoryCard(
                        product: displayProduct,
                        locationName: authManager.currentLocation?.name,
                        currentLocationId: authManager.currentLocation?.id,
                        storeStock: storeStock,
                        storeStockLoaded: storeStockLoaded,
                        knownLocations: authManager.availableLocations.count
                    ) { activityFullView }
                }

                // FIFO lots
                if authManager.isOwner || authManager.isManager {
                    ProductLotsSection(
                        batches: batchViewModel.batches,
                        isLoading: batchViewModel.isLoading,
                        productAging: batchViewModel.productAging,
                        cashAtRisk: batchViewModel.cashAtRisk,
                        stockHere: displayProduct.totalInventory ?? 0,
                        onSelectBatch: { sheet = .batch($0) }
                    )
                }

                // Recent Activity (product-scoped)
                ProductRecentActivitySection(
                    items: activityViewModel.combinedActivity,
                    isLoading: activityViewModel.isLoading
                ) { activityFullView }

                ProductDetailsCard(product: displayProduct)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .navigationTitle("Producto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEditPrice {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Editar precio", systemImage: "pencil") {
                        sheet = .editPrice
                    }
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
                    onComplete: { _ in
                        Task { await refreshDependentData() }
                    }
                )
            case .adjust(let type):
                AdjustmentFormView(
                    adjustmentType: type,
                    viewModel: inventoryViewModel,
                    product: displayProduct,
                    onComplete: {
                        Task { await refreshDependentData() }
                    }
                )
            case .pause:
                PauseProductView(product: displayProduct) { applyPauseChange($0) }
            case .batch(let batchId):
                BatchDetailView(batchId: batchId, productName: displayProduct.displayName)
            case .suppliers:
                CostSupplierSheet(
                    suppliers: costSupplierViewModel.suppliers,
                    costHistory: costSupplierViewModel.costHistory,
                    isLoading: costSupplierViewModel.isLoading,
                    onDone: { self.sheet = nil }
                )
            }
        }
        .task {
            RecentProductsStore.record(product.id) // Productos' start screen
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
        .alert("Square", isPresented: $inventoryViewModel.showsSquareWarning) {
            Button("OK") {}
        } message: {
            Text(inventoryViewModel.squareWarning ?? "")
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
    
    // MARK: - Header (identity + economics)

    private static let photoSize: CGFloat = 64

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                productPhoto

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    // Never truncated: pharmacy names run long (strength, form, count);
                    // the card grows instead.
                    Text(displayProduct.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                    codesLine
                }

                Spacer(minLength: 0)
            }

            ProductEconomicsBox(
                product: displayProduct,
                canViewCosts: authManager.canViewCosts,
                isCostLoading: isCostLoading,
                unitCost: unitCost,
                supplierCount: costSupplierViewModel.suppliers.count,
                onShowSuppliers: { sheet = .suppliers }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var productPhoto: some View {
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
                        CachedProductImage(url: displayUrl, targetSize: CGSize(width: Self.photoSize, height: Self.photoSize)) {
                            productPlaceholder
                        }
                        .frame(width: Self.photoSize, height: Self.photoSize)
                        .clipShape(.rect(cornerRadius: DS.Radius.l))
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
            // Offset past the corner so it doesn't cover the package art.
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
                        .font(.body)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.tint).frame(width: 22, height: 22))
                        .frame(width: DS.minTapSize, height: DS.minTapSize)
                        .contentShape(.rect)
                }
                .offset(x: DS.Spacing.l, y: DS.Spacing.l)
                .accessibilityLabel("Cambiar foto")
            }

            if isUploadingImage {
                ProgressView()
                    .frame(width: Self.photoSize, height: Self.photoSize)
                    .background(Color.black.opacity(0.3))
                    .clipShape(.rect(cornerRadius: DS.Radius.l))
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
    }

    /// SKU · barcode on one line, monospaced: scannable, never decorative.
    @ViewBuilder
    private var codesLine: some View {
        let sku = displayProduct.sku
        let gtin = displayProduct.gtin.flatMap { $0.isEmpty ? nil : $0 }
        if sku != nil || gtin != nil {
            HStack(spacing: DS.Spacing.xs) {
                if let sku {
                    Text(sku)
                        .accessibilityLabel("SKU \(sku)")
                }
                if sku != nil, gtin != nil {
                    Text("·")
                        .accessibilityHidden(true)
                }
                if let gtin {
                    Label(gtin, systemImage: "barcode")
                        .accessibilityLabel("Código de barras \(gtin)")
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
    }

    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.l)
                .fill(.fill.tertiary)
                .frame(width: Self.photoSize, height: Self.photoSize)

            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Economics

    /// The one cost this screen shows, and its margin uses: the latest supplier
    /// cost (preferred, else first), or the average cost without a supplier.
    private var unitCost: UnitCost? {
        let lastPurchase = Dictionary(
            costSupplierViewModel.costHistory.map { ($0.supplierId, $0.currentCost?.effectiveAt) },
            uniquingKeysWith: { first, _ in first }
        )
        return UnitCost.pick(
            suppliers: costSupplierViewModel.suppliers.map {
                UnitCost.Supplier(id: $0.id, name: $0.name, cost: $0.costDouble,
                                  isPreferred: $0.isPreferred, lastPurchase: lastPurchase[$0.id] ?? nil)
            },
            averageCost: displayProduct.averageCost
        )
    }

    /// Suppliers still loading: a placeholder instead of the average cost flipping to theirs.
    private var isCostLoading: Bool {
        costSupplierViewModel.isLoading && costSupplierViewModel.suppliers.isEmpty
    }

    // MARK: - Inventory

    private var activityFullView: some View {
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
    }

    // MARK: - Action Bar

    /// Ajustar + Recibir inventario, pinned at the bottom (both ≥ 44pt).
    @ViewBuilder
    private var actionBar: some View {
        if authManager.canManageInventory {
            VStack(spacing: DS.Spacing.xs) {
                if !canAddStock {
                    Label("Este producto se vende solo en otra tienda", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: DS.Spacing.m) {
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
                        switch pauseAction {
                        case .pause:
                            Divider()
                            Button { sheet = .pause } label: { Label("Pausar", systemImage: "pause.circle") }
                        case .resume:
                            Divider()
                            Button { Task { await resume() } } label: { Label("Reanudar", systemImage: "play.circle") }
                        case nil:
                            EmptyView()
                        }
                    } label: {
                        Label("Ajustar", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)

                    if canAddStock {
                        Button {
                            sheet = .receive
                        } label: {
                            Label("Recibir inventario", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            .padding(.vertical, DS.Spacing.s)
            .background(.bar)
        }
    }
    
    
    private func selectAdjustment(_ type: AdjustmentType) {
        sheet = .adjust(type)
    }

    // MARK: - Pause (stock alerts O5)

    private var pauseAction: PauseForm.Action? {
        PauseForm.action(alert: displayProduct.stockAlert, isManager: authManager.isManager,
                         tracksInventory: displayProduct.tracksInventory,
                         soldOnlyAtLocationId: displayProduct.soldOnlyAtLocationId,
                         currentLocationId: authManager.currentLocation?.id)
    }

    /// The API answers the updated row (stockAlert included): no refetch.
    private func applyPauseChange(_ updated: Product) {
        currentProduct = updated
        onProductUpdated?(updated)
        ProductCacheManager.shared.saveProduct(updated)
    }

    private func resume() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        do {
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .resumeProduct(id: product.id), queryParams: ["locationId": locationId])
            applyPauseChange(response.data)
        } catch NetworkError.cancelled {
        } catch {
            refreshErrorMessage = (error as? NetworkError)?.errorDescription ?? "No se pudo reanudar el producto."
            showRefreshError = true
        }
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
        guard let locationId = authManager.currentLocation?.id else { return }
        await activityViewModel.loadActivity(productId: displayProduct.id, locationId: locationId)
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
    case suppliers
    case pause

    var id: String {
        switch self {
        case .editPrice: "editPrice"
        case .receive: "receive"
        case .adjust(let type): "adjust-\(type.id)"
        case .batch(let batchId): "batch-\(batchId)"
        case .suppliers: "suppliers"
        case .pause: "pause"
        }
    }
}
