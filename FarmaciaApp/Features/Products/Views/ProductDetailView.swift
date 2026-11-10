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
            VStack(spacing: DS.Spacing.m) {
                // Identity + price, cost, margin and where the cost comes from
                headerCard

                if displayProduct.tracksInventory != false {
                    inventoryCard
                }

                // FIFO lots
                if authManager.isOwner || authManager.isManager {
                    fifoBatchSection
                }

                // Recent Activity (product-scoped)
                recentActivitySection

                detailsCard
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
            case .batch(let batchId):
                BatchDetailView(batchId: batchId, productName: displayProduct.displayName)
            case .suppliers:
                NavigationStack {
                    ScrollView {
                        costSupplierHistorySection
                            .padding()
                    }
                    .navigationTitle("Costos y proveedores")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { self.sheet = nil }
                        }
                    }
                }
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

            economicsBox

            if authManager.canViewCosts, !isCostLoading, let unitCost {
                provenanceRow(unitCost)
            }
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

    private var economicsBox: some View {
        // Cost: never for a cashier, even if a cached row still carries one.
        let cost = authManager.canViewCosts && !isCostLoading ? unitCost?.cost : nil
        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Precio de venta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let price = displayProduct.sellingPrice {
                        MoneyText(amount: price)
                    } else {
                        Text("No definido")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if authManager.canViewCosts {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text("Costo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isCostLoading {
                            MoneyText(amount: 0)
                                .redacted(reason: .placeholder)
                                .accessibilityLabel("Cargando costo")
                        } else if let cost {
                            MoneyText(amount: cost)
                        } else {
                            Text("—")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let price = displayProduct.sellingPrice, let cost, let margin = PriceMargin(price: price, cost: cost) {
                Divider()
                marginLine(margin)
            }
        }
        .padding(DS.Spacing.m)
        .background(Color(.systemBackground), in: .rect(cornerRadius: DS.Radius.l))
    }

    /// "Margen 55.5% · $122.00 por unidad", currency stated once. One Text, so it wraps.
    private func marginLine(_ margin: PriceMargin) -> some View {
        let glyph = margin.tone == .positive
            ? Text("")
            : Text("\(Image(systemName: "exclamationmark.triangle.fill")) ").foregroundStyle(margin.tone.color)
        let percent = Text(String(format: "%.1f%%", margin.percent))
            .fontWeight(.semibold)
            .foregroundStyle(margin.tone.color)
        let perUnit = Text(ReportFormat.currency(margin.perUnit))
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
        return HStack(alignment: .firstTextBaseline) {
            Text("Margen \(glyph)\(percent) · \(perUnit) por unidad")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            Text(displayProduct.currency ?? "MXN")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Where the cost comes from ("Simi · Mejor precio · compra 1 nov"); opens costs and suppliers.
    /// The cost itself is printed once, above.
    private func provenanceRow(_ unitCost: UnitCost) -> some View {
        Button {
            sheet = .suppliers
        } label: {
            HStack(spacing: DS.Spacing.s) {
                switch unitCost.source {
                case .supplier(let name, let lastPurchase):
                    Image(systemName: "building.2")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(name)
                                .fontWeight(.medium)
                            if unitCost.isBestPrice {
                                ToneBadge("Mejor precio", tone: .positive)
                            }
                        }
                        let detail = [
                            lastPurchase.map { "compra \(DisplayDate.shortDay($0))" },
                            unitCost.showsAllSuppliers ? "\(costSupplierViewModel.suppliers.count) proveedores" : nil,
                        ].compactMap { $0 }
                        if !detail.isEmpty {
                            Text(detail.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                case .average:
                    Image(systemName: "function")
                        .foregroundStyle(.secondary)
                    Text("Costo promedio del inventario")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
            .frame(minHeight: DS.minTapSize)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ver costos y proveedores")
    }

    // MARK: - Inventory

    private var inventoryCard: some View {
        let here = displayProduct.totalInventory ?? 0
        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Label("Inventario", systemImage: "shippingbox")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    activityFullView
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        Text("Movimientos")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .frame(minHeight: DS.minTapSize)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text("\(here)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("uds en esta tienda")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let name = authManager.currentLocation?.name {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if StockLevel(quantity: here) == .out {
                StatusLabel("Agotado en esta tienda", tone: .critical)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            otherStoresRows
        }
        .card()
    }

    /// The other stores' stock (tasks/other-stores-stock-epic.md). Hidden when
    /// there's none to show: offline, failed fetch, untracked, or sold only here.
    /// A store without it is a neutral "0 uds", not an alarm.
    @ViewBuilder
    private var otherStoresRows: some View {
        let stores = StoreStock.others(storeStock, currentLocationId: authManager.currentLocation?.id)
        if !storeStockLoaded && expectsStoreStock {
            Divider()
            // First load: placeholder rows, so the block visibly fills in.
            ForEach(0..<StoreStock.placeholderRows(knownLocations: authManager.availableLocations.count), id: \.self) { _ in
                LabeledContent("Sucursal") { Text("00 uds") }
                    .font(.subheadline)
            }
            .redacted(reason: .placeholder)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cargando existencias")
        } else if !stores.isEmpty {
            Divider()
            let here = displayProduct.totalInventory ?? 0
            ForEach(stores) { store in
                let standsOut = store.standsOut(hereQuantity: here)
                LabeledContent {
                    Text("\(store.quantity) uds")
                        .monospacedDigit()
                        .fontWeight(standsOut ? .bold : .regular)
                        .foregroundStyle(standsOut ? Tone.positive.color : (store.quantity > 0 ? .primary : .secondary))
                } label: {
                    Label(store.locationName, systemImage: "building.2")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

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
    
    // MARK: - Recent Activity Section (Product-Scoped)

    /// Nothing happened yet → one 44pt row; otherwise the last 5 and "Ver toda la actividad".
    @ViewBuilder
    private var recentActivitySection: some View {
        let items = activityViewModel.combinedActivity
        switch ListPreview(count: items.count, limit: 5) {
        case .collapsed:
            EmptyRow(text: activityViewModel.isLoading ? "Cargando movimientos…" : "Sin movimientos aún",
                     systemImage: "clock.arrow.circlepath")
        case .list(let shown, let hasMore):
            let visible = Array(items.prefix(shown))
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack {
                    Label("Actividad reciente", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Spacer()
                    if activityViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ForEach(visible) { item in
                    activityRow(item)
                    if item.id != visible.last?.id {
                        Divider()
                    }
                }

                if hasMore {
                    NavigationLink {
                        activityFullView
                    } label: {
                        HStack {
                            Text("Ver toda la actividad")
                            Spacer()
                            Text("\(items.count) en total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .frame(minHeight: DS.minTapSize)
                    }
                }
            }
            .card()
        }
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
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Detalles")
                .font(.headline)

            // The Square description only when it says something the name doesn't.
            if let description = displayProduct.squareDescription, !description.isEmpty,
               description != displayProduct.displayName {
                detailRow(title: "Descripción", value: description)
            }

            if let category = displayProduct.category {
                detailRow(title: "Categoría", value: category.name)
            }

            if let createdAt = displayProduct.createdAt {
                detailRow(title: "Creado", value: DisplayDate.day(createdAt))
            }

            squareSyncLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func detailRow(title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    /// "Square POS sincronizado hace 2 días" — words + glyph, not a dot alone.
    private var squareSyncLine: some View {
        let synced = displayProduct.hasSquareSync == true
        let tone: Tone = synced ? .positive : .caution
        let detail = synced
            ? displayProduct.squareDataSyncedAt.map { "sincronizado \(DisplayDate.relative($0))" } ?? "sincronizado"
            : "solo local, no visible en Square"
        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: synced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tone.color)
            Text("Square POS")
                .fontWeight(.medium)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
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
    
    // MARK: - FIFO Batch Breakdown Section

    private var fifoBatchSection: some View {
        let batches = batchViewModel.batches
        return VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Label("Lotes (FIFO)", systemImage: "square.stack.3d.up")
                    .font(.headline)

                Spacer()

                if batchViewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if !batches.isEmpty {
                    Text("\(batches.count) lote\(batches.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if batches.isEmpty && !batchViewModel.isLoading {
                Text("Sin lotes de inventario")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !batches.isEmpty {
                // One chip, neutral unless something needs attention; shelf age in words.
                let alert = ProductAlert.worst(
                    lots: LotSummary(lots: batches),
                    stockHere: displayProduct.totalInventory ?? 0,
                    risk: batchViewModel.productAging?.riskLevel
                )
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                    ToneBadge(alert.label, tone: alert.tone, systemImage: alert.systemImage)
                    if let sentence = AgingSentence.text(lots: batches) {
                        Text(sentence)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let aging = batchViewModel.productAging, !aging.bucketDistribution.isEmpty {
                    agingBar(aging)
                }

                // Cash at risk callout (if any >90d inventory)
                let atRiskCash = batchViewModel.cashAtRisk
                if atRiskCash > 0 {
                    StatusLabel("\(ReportFormat.currency(atRiskCash)) con más de 90 días", tone: .critical)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                // Lots in the order FIFO sells them (first 3 = next to sell, expand for all)
                let sortedBatches = BatchValuation.fifoOrder(batches)
                let nextOutId = BatchValuation.nextOut(batches)?.id
                if case .list(let shown, let hasMore) = ListPreview(count: sortedBatches.count, limit: 3) {
                    let batchesToShow = showAllBatches ? sortedBatches : Array(sortedBatches.prefix(shown))
                    ForEach(batchesToShow) { batch in
                        Divider()
                        Button {
                            sheet = .batch(batch.batchId)
                        } label: {
                            batchRow(batch, isNextOut: batch.id == nextOutId)
                        }
                        .buttonStyle(.plain)
                    }

                    if hasMore {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllBatches.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showAllBatches ? "Ver menos" : "Ver todos")
                                Image(systemName: showAllBatches ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .frame(minHeight: DS.minTapSize)
                            .contentShape(.rect)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// The aging service's buckets as a bar, with text labels so it isn't color alone.
    private func agingBar(_ aging: ProductAgingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(aging.bucketDistribution) { bucket in
                        let width = max(2, geometry.size.width * CGFloat(bucket.percentageOfTotal / 100))
                        Rectangle()
                            .fill(BatchAge.tone(days: bucket.bucket.min).color)
                            .frame(width: width, height: 6)
                    }
                }
                .clipShape(.rect(cornerRadius: 3))
            }
            .frame(height: 6)
            .accessibilityHidden(true)

            HStack(spacing: DS.Spacing.s) {
                ForEach(aging.bucketDistribution) { bucket in
                    HStack(spacing: 3) {
                        Text("\(bucket.unitCount)")
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text(bucket.bucket.label)
                    }
                }
                Spacer()
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
    }

    /// "2 uds × $98.00 · Sale siguiente … $196.00 valor del lote", received line, metadata, expiry row.
    private func batchRow(_ batch: BatchValuation, isNextOut: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text("\(batch.quantity) uds × \(ReportFormat.currency(batch.unitCost))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                if isNextOut {
                    ToneBadge("Sale siguiente", tone: .info)
                }
                Spacer(minLength: DS.Spacing.s)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(ReportFormat.currency(batch.value))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("valor del lote")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(receivedLine(batch))
                .font(.caption)
                .foregroundStyle(.secondary)

            let pills = batchMetadataPills(batch)
            if !pills.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(pills, id: \.label) { pill in
                            ToneBadge(pill.label, color: pill.color, systemImage: pill.icon)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            expiryRow(batch)
        }
        .padding(.vertical, DS.Spacing.xxs)
        .contentShape(.rect)
    }

    /// "Recibido 1 nov · saldo inicial · hace 2 días".
    private func receivedLine(_ batch: BatchValuation) -> String {
        var parts = ["Recibido \(DisplayDate.shortDay(batch.receivedAt))"]
        if batch.source != nil {
            parts.append(batch.sourceLabel.lowercased())
        }
        parts.append(batch.age == 1 ? "hace 1 día" : "hace \(batch.age) días")
        return parts.joined(separator: " · ")
    }

    /// The caducidad is the field that matters most for a medicine: always a row, tinted by `Expiry.tone`.
    @ViewBuilder
    private func expiryRow(_ batch: BatchValuation) -> some View {
        if let expiry = batch.expiryDate {
            let days = Expiry.daysUntil(expiry)
            let tone = Expiry.tone(daysUntil: days)
            let text = days < 0
                ? "\(Expiry.display(expiry)) · \(Expiry.countdown(daysUntil: days))"
                : "Vence \(Expiry.display(expiry)) · \(Expiry.countdown(daysUntil: days))"
            Label(text, systemImage: tone.systemImage)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(tone == .neutral ? .primary : tone.color)
                .padding(.horizontal, DS.Spacing.s)
                .padding(.vertical, DS.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((tone == .neutral ? Color(.systemGray5) : tone.color.opacity(0.12)), in: .rect(cornerRadius: DS.Radius.m))
        } else {
            Label("Sin caducidad registrada", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private struct BatchPill: Hashable {
        let icon: String
        let label: String
        let color: Color
    }

    /// Lot number, supplier, invoice. The expiry has its own row.
    private func batchMetadataPills(_ batch: BatchValuation) -> [BatchPill] {
        var pills: [BatchPill] = []

        if let lot = batch.batchNumber, !lot.isEmpty {
            pills.append(BatchPill(icon: "number", label: lot, color: .purple))
        }

        if let supplier = batch.supplierName, !supplier.isEmpty {
            pills.append(BatchPill(icon: "building.2", label: supplier, color: .blue))
        }

        if let invoice = batch.invoiceNumber, !invoice.isEmpty {
            pills.append(BatchPill(icon: "doc.text", label: invoice, color: .gray))
        }

        return pills
    }
    
    // MARK: - Cost & Supplier History Section
    
    private var costSupplierHistorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
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
                        Text("c/u")
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
                                Text("c/u")
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
                                    
                                    Text("\(group.costHistory.count) registro\(group.costHistory.count == 1 ? "" : "s")")
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
                                        
                                        Text(DisplayDate.day(entry.effectiveAt))
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
                                    Text("+ \(group.costHistory.count - 10) registros más")
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
    case suppliers

    var id: String {
        switch self {
        case .editPrice: "editPrice"
        case .receive: "receive"
        case .adjust(let type): "adjust-\(type.id)"
        case .batch(let batchId): "batch-\(batchId)"
        case .suppliers: "suppliers"
        }
    }
}
