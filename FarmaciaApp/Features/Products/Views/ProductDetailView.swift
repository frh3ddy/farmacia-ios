import SwiftUI

// MARK: - Product Detail View
// This is the unified product hub — catalog info, pricing, stock,
// inventory actions (receive/adjust), and recent activity in one place.

struct ProductDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    
    @State private var showEditPrice = false
    @State private var isRefreshing = false
    @State private var currentProduct: Product?
    
    // Inventory action sheets
    @State private var showReceiveSheet = false
    @State private var showAdjustmentSheet = false
    @State private var selectedAdjustmentType: AdjustmentType = .damage
    
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
    @State private var showImagePicker = false
    @State private var showImageSourcePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var isUploadingImage = false
    @State private var uploadedImageUrl: String? = nil
    @State private var showImageUploadError = false
    @State private var showImageViewer = false
    
    private var displayProduct: Product {
        currentProduct ?? product
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Product Header
                productHeader
                
                // Price Card
                priceCard
                
                // Inventory Card (with actions)
                inventoryCard
                
                // FIFO Batch Breakdown
                if authManager.isOwner || authManager.isManager {
                    fifoBatchSection
                }
                
                // Cost & Supplier History
                costSupplierHistorySection
                
                // Recent Activity (product-scoped)
                recentActivitySection
                
                // Details Card
                detailsCard
                
                // Square Sync Status
                squareSyncCard
            }
            .padding()
        }
        .navigationTitle("Product Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if authManager.isOwner || authManager.isManager {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEditPrice = true
                        } label: {
                            Label("Edit Price", systemImage: "dollarsign.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditPrice) {
            EditPriceView(product: displayProduct) { updatedProduct in
                currentProduct = updatedProduct
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView(
                viewModel: inventoryViewModel,
                preSelectedProduct: displayProduct,
                onComplete: {
                    Task {
                        await refreshProduct()
                        async let activityLoad: () = loadActivity()
                        async let batchLoad: () = loadBatchData()
                        async let costSupplierLoad: () = loadCostSupplierData()
                        _ = await (activityLoad, batchLoad, costSupplierLoad)
                    }
                }
            )
        }
        .sheet(isPresented: $showAdjustmentSheet) {
            AdjustmentFormView(
                adjustmentType: selectedAdjustmentType,
                viewModel: inventoryViewModel,
                preSelectedProduct: displayProduct,
                onComplete: {
                    Task {
                        await refreshProduct()
                        async let activityLoad: () = loadActivity()
                        async let batchLoad: () = loadBatchData()
                        async let costSupplierLoad: () = loadCostSupplierData()
                        _ = await (activityLoad, batchLoad, costSupplierLoad)
                    }
                }
            )
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
            // Load suppliers for receive form
            await inventoryViewModel.loadProducts()
            await inventoryViewModel.loadSuppliers()
            // Load product-scoped activity, batch, and cost/supplier data in parallel
            async let activityLoad: () = loadActivity()
            async let batchLoad: () = loadBatchData()
            async let costSupplierLoad: () = loadCostSupplierData()
            _ = await (activityLoad, batchLoad, costSupplierLoad)
        }
        .refreshable {
            await refreshProduct()
            async let activityLoad: () = loadActivity()
            async let batchLoad: () = loadBatchData()
            async let costSupplierLoad: () = loadCostSupplierData()
            _ = await (activityLoad, batchLoad, costSupplierLoad)
        }
        .alert("Error", isPresented: $inventoryViewModel.showError) {
            Button("OK") {}
        } message: {
            Text(inventoryViewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $inventoryViewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(inventoryViewModel.successMessage ?? "Operation completed")
        }
        .alert("Image Upload Failed", isPresented: $showImageUploadError) {
            Button("OK") {}
        } message: {
            Text("Could not upload the product image. Please try again.")
        }
    }
    
    // MARK: - Product Header
    
    private var productHeader: some View {
        VStack(spacing: 12) {
            // Product Image or Placeholder
            ZStack(alignment: .bottomTrailing) {
                // Image area — tapping opens full-screen viewer
                Group {
                    if let imageUrl = uploadedImageUrl ?? displayProduct.squareImageUrl, let url = URL(string: imageUrl) {
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
                        .frame(width: 100, height: 100)
                        .cornerRadius(16)
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
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.blue).frame(width: 28, height: 28))
                    }
                    .offset(x: 4, y: 4)
                }
                
                if isUploadingImage {
                    ProgressView()
                        .frame(width: 100, height: 100)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(16)
                }
            }
            .confirmationDialog("Change Product Image", isPresented: $showImageSourcePicker) {
                Button("Take Photo") {
                    imagePickerSource = .camera
                    showImagePicker = true
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {} // camera availability check
                Button("Choose from Library") {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imagePickerSource) { image in
                    Task {
                        await uploadProductImage(image)
                    }
                }
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
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray5))
                .frame(width: 100, height: 100)
            
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Price Card
    
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundColor(.green)
                Text("Pricing")
                    .font(.headline)
                
                Spacer()
                
                if authManager.isOwner || authManager.isManager {
                    Button("Edit") {
                        showEditPrice = true
                    }
                    .font(.subheadline)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selling Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let price = displayProduct.formattedPrice {
                        Text(price)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        Text("Not set")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Avg. Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let cost = displayProduct.formattedCost {
                        Text(cost)
                            .font(.title3)
                            .fontWeight(.semibold)
                    } else {
                        Text("N/A")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Margin
            if let margin = displayProduct.profitMargin {
                HStack {
                    Text("Profit Margin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f%%", margin))
                        .font(.headline)
                        .foregroundColor(margin >= 20 ? .green : (margin >= 10 ? .orange : .red))
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Inventory Card (with Actions)
    
    private var inventoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.blue)
                Text("Inventory")
                    .font(.headline)
                
                Spacer()
                
                // Aging risk badge (from aging service)
                if let risk = batchViewModel.productAging?.riskLevel, risk != .low {
                    agingRiskBadge(risk)
                }
                
                stockStatusBadge
            }
            
            Divider()
            
            // Stock display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("In Stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(displayProduct.totalInventory ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor((displayProduct.totalInventory ?? 0) > 0 ? .primary : .red)
                    
                    Text("units")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Action buttons (permission gated)
            if authManager.canManageInventory {
                Divider()
                
                HStack(spacing: 12) {
                    // Receive Stock button
                    Button {
                        showReceiveSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline)
                            Text("Receive Stock")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    // Adjust Stock button (menu for type selection)
                    Menu {
                        ForEach(quickAdjustmentTypes, id: \.self) { type in
                            Button {
                                selectedAdjustmentType = type
                                showAdjustmentSheet = true
                            } label: {
                                Label(type.displayName, systemImage: type.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.subheadline)
                            Text("Adjust Stock")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private let quickAdjustmentTypes: [AdjustmentType] = [
        .damage, .expired, .found, .returnType, .countCorrection, .theft, .writeOff
    ]
    
    private var stockStatusBadge: some View {
        let stock = displayProduct.totalInventory ?? 0
        let (text, color): (String, Color) = {
            if stock == 0 {
                return ("Out of Stock", .red)
            } else if stock < 10 {
                return ("Low Stock", .orange)
            } else {
                return ("In Stock", .green)
            }
        }()
        
        return Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private func agingRiskBadge(_ risk: InventoryRiskLevel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: risk.icon)
                .font(.caption2)
            Text(risk.displayName)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(risk.color.opacity(0.15))
        .foregroundColor(risk.color)
        .cornerRadius(8)
    }
    
    // MARK: - Recent Activity Section (Product-Scoped)
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.indigo)
                Text("Recent Activity")
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
                        .foregroundColor(.secondary)
                    Text("No activity yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                            receivings: activityViewModel.receivings,
                            adjustments: activityViewModel.adjustments
                        )
                    } label: {
                        HStack {
                            Text("View All Activity")
                                .font(.subheadline)
                            Spacer()
                            Text("\(activityViewModel.combinedActivity.count) total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func activityRow(_ item: ProductActivityItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundColor(item.iconColor)
                .frame(width: 28, height: 28)
                .background(item.iconColor.opacity(0.12))
                .cornerRadius(6)
            
            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quantity change
            Text(item.quantityDisplay)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(item.quantityColor)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.purple)
                Text("Details")
                    .font(.headline)
            }
            
            Divider()
            
            if let description = displayProduct.squareDescription, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.subheadline)
                }
            }
            
            if let category = displayProduct.category {
                detailRow(title: "Category", value: category.name)
            }
            
            if let createdAt = displayProduct.createdAt {
                detailRow(title: "Created", value: createdAt.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
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
                    .foregroundColor(.orange)
                Text("Square Sync")
                    .font(.headline)
            }
            
            Divider()
            
            HStack {
                if displayProduct.hasSquareSync == true {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("Synced to Square")
                            .font(.subheadline)
                        Text("Product is visible in Square POS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Local Only")
                            .font(.subheadline)
                        Text("Product is not synced to Square POS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let syncedAt = displayProduct.squareDataSyncedAt {
                Text("Last synced: \(syncedAt.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Actions
    
    private func refreshProduct() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        isRefreshing = true
        
        do {
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .getProduct(id: product.id),
                queryParams: ["locationId": locationId]
            )
            currentProduct = response.data
        } catch {
            // Silent fail - keep showing current data
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
        // Compress image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUploadingImage = true
        defer { isUploadingImage = false }
        
        do {
            let response: ImageUploadResponse = try await APIClient.shared.uploadImage(
                endpoint: .uploadProductImage(id: displayProduct.id),
                imageData: imageData,
                filename: "product_\(displayProduct.id).jpg"
            )
            if let url = response.imageUrl {
                uploadedImageUrl = url
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
                    .foregroundColor(.teal)
                Text("FIFO Batches")
                    .font(.headline)
                
                Spacer()
                
                if batchViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !batchViewModel.batches.isEmpty {
                    Text("\(batchViewModel.batches.count) batch\(batchViewModel.batches.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            if batchViewModel.batches.isEmpty && !batchViewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No inventory batches")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(.red)
                        }
                        if expiringSoonCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.caption2)
                                Text("\(expiringSoonCount) expiring soon")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.orange)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Individual batches (show first 3, expand for all)
                let batchesToShow = showAllBatches ? batchViewModel.batches : Array(batchViewModel.batches.prefix(3))
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
                            Text(showAllBatches ? "Show Less" : "Show All \(batchViewModel.batches.count) Batches")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: showAllBatches ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
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
                .foregroundColor(aging.riskLevel.color)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(aging.formattedCashTiedUp)
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("tied up")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                    .cornerRadius(3)
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
                        .foregroundColor(.secondary)
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
                        .foregroundColor(.red)
                    Text(String(format: "$%.2f at risk (>90 days)", atRiskCash))
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.08))
                .cornerRadius(6)
            }
        }
        .padding(10)
        .background(aging.riskLevel.color.opacity(0.06))
        .cornerRadius(10)
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
        .cornerRadius(8)
    }
    
    private func batchRow(_ batch: BatchValuation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Quantity, unit cost, and value
            HStack(spacing: 10) {
                // Age indicator (or expiry warning)
                if batch.isExpired {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if batch.expiresWithin(days: 90) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Circle()
                        .fill(batchAgeColor(batch.age))
                        .frame(width: 10, height: 10)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(batch.quantity) units")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("@ $\(batch.unitCost)/ea")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Row 2: Age + received date + source
                    HStack(spacing: 4) {
                        Text("\(batch.age)d old")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\u{2022}")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(batch.receivedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if batch.source != nil {
                            Text("\u{2022}")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(batch.sourceLabel)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Batch value
                Text("$\(batch.value)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
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
                            .foregroundColor(pill.color)
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
                pills.append(BatchPill(icon: "xmark.circle", label: "Expired \(formatted)", color: .red))
            } else if batch.expiresWithin(days: 90) {
                pills.append(BatchPill(icon: "clock", label: "Exp \(formatted)", color: .orange))
            } else {
                pills.append(BatchPill(icon: "calendar", label: "Exp \(formatted)", color: .green))
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
                    .foregroundColor(.cyan)
                Text("Cost & Supplier History")
                    .font(.headline)
                
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
                    Text("Loading supplier data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if costSupplierViewModel.suppliers.isEmpty && costSupplierViewModel.costHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No supplier data yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Supplier costs will appear here when products are received from suppliers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // Current Suppliers section (from SupplierProduct)
                if !costSupplierViewModel.suppliers.isEmpty {
                    Text("Current Suppliers")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                                    .foregroundColor(supplier.isPreferred ? .blue : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(supplier.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if supplier.isPreferred {
                                        Text("Preferred")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                    }
                                }
                                if let notes = supplier.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(supplier.formattedCost)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("per unit")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
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
                    
                    Text("Cost History by Supplier")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                                        .foregroundColor(.primary)
                                    
                                    if let current = group.currentCost {
                                        Text(current.formattedCost)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    
                                    // Cost trend indicator
                                    if let trend = group.costTrend {
                                        HStack(spacing: 2) {
                                            Image(systemName: trend.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.caption2)
                                            Text(String(format: "%.1f%%", abs(trend.percent)))
                                                .font(.caption2)
                                        }
                                        .foregroundColor(trend.change > 0 ? .red : .green)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(group.costHistory.count) entries")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Image(systemName: expandedSupplierHistory == group.supplierId ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
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
                                            .foregroundColor(.secondary)
                                            .frame(width: 80, alignment: .leading)
                                        
                                        Text(entry.formattedCost)
                                            .font(.caption)
                                            .fontWeight(entry.isCurrent ? .semibold : .regular)
                                        
                                        Spacer()
                                        
                                        Text(entry.sourceLabel)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        if entry.isCurrent {
                                            Text("Current")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.blue)
                                                .cornerRadius(3)
                                        }
                                    }
                                    .padding(.leading, 16)
                                }
                                
                                if group.costHistory.count > 10 {
                                    Text("+ \(group.costHistory.count - 10) more entries")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
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
        .cornerRadius(16)
    }
}

// MARK: - Product Activity Item (unified timeline model)

struct ProductActivityItem: Identifiable {
    enum ActivityKind {
        case receiving
        case adjustment(AdjustmentType)
    }
    
    let id: String
    let kind: ActivityKind
    let title: String
    let subtitle: String
    let date: Date
    let quantity: Int
    let icon: String
    let iconColor: Color
    
    var quantityDisplay: String {
        if quantity > 0 {
            return "+\(quantity)"
        }
        return "\(quantity)"
    }
    
    var quantityColor: Color {
        quantity > 0 ? .green : .red
    }
}

// MARK: - Product Activity ViewModel

@MainActor
class ProductActivityViewModel: ObservableObject {
    @Published var receivings: [InventoryReceiving] = []
    @Published var adjustments: [InventoryAdjustment] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    /// Combined and chronologically sorted activity for the product
    var combinedActivity: [ProductActivityItem] {
        var items: [ProductActivityItem] = []
        
        // Convert receivings
        for r in receivings {
            items.append(ProductActivityItem(
                id: "recv-\(r.id)",
                kind: .receiving,
                title: "Received \(r.quantity) units",
                subtitle: r.supplier?.name ?? r.invoiceNumber.map { "Invoice: \($0)" } ?? r.formattedDate,
                date: r.receivedAt,
                quantity: r.quantity,
                icon: "arrow.down.circle.fill",
                iconColor: .blue
            ))
        }
        
        // Convert adjustments
        for a in adjustments {
            let displayQty = a.type.isNegative ? -abs(a.quantity) : a.quantity
            items.append(ProductActivityItem(
                id: "adj-\(a.id)",
                kind: .adjustment(a.type),
                title: "\(a.type.displayName)",
                subtitle: a.reason ?? a.notes ?? a.adjustedAt.formatted(date: .abbreviated, time: .shortened),
                date: a.adjustedAt,
                quantity: displayQty,
                icon: a.type.icon,
                iconColor: a.type.isPositive ? .green : (a.type.isNegative ? .red : .orange)
            ))
        }
        
        // Sort by date, newest first
        return items.sorted { $0.date > $1.date }
    }
    
    func loadActivity(productId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        guard !Task.isCancelled else { return }
        
        // Load both in parallel
        async let receivingsResult: () = loadReceivings(productId: productId)
        async let adjustmentsResult: () = loadAdjustments(productId: productId)
        
        _ = await (receivingsResult, adjustmentsResult)
    }
    
    private func loadReceivings(productId: String) async {
        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByProduct(productId: productId)
            )
            receivings = response.data
        } catch {
            // Silent fail — receivings are supplementary
            print("Failed to load product receivings: \(error)")
        }
    }
    
    private func loadAdjustments(productId: String) async {
        do {
            let response: AdjustmentListResponse = try await apiClient.request(
                endpoint: .adjustmentsByProduct(productId: productId)
            )
            adjustments = response.data
        } catch {
            // Silent fail — adjustments are supplementary
            print("Failed to load product adjustments: \(error)")
        }
    }
}

// MARK: - Product Activity Full View (all history for a product)

struct ProductActivityFullView: View {
    let product: Product
    let receivings: [InventoryReceiving]
    let adjustments: [InventoryAdjustment]
    
    @State private var selectedSegment: ActivitySegment = .all
    
    enum ActivitySegment: String, CaseIterable {
        case all = "All"
        case receivings = "Receivings"
        case adjustments = "Adjustments"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Activity", selection: $selectedSegment) {
                ForEach(ActivitySegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                switch selectedSegment {
                case .all:
                    let allItems = combinedItems
                    if allItems.isEmpty {
                        emptyState("No activity recorded")
                    } else {
                        ForEach(allItems) { item in
                            ActivityFullRow(item: item)
                        }
                    }
                    
                case .receivings:
                    if receivings.isEmpty {
                        emptyState("No receivings recorded")
                    } else {
                        ForEach(receivings) { receiving in
                            ReceivingRow(receiving: receiving)
                        }
                    }
                    
                case .adjustments:
                    if adjustments.isEmpty {
                        emptyState("No adjustments recorded")
                    } else {
                        ForEach(adjustments) { adjustment in
                            AdjustmentRow(adjustment: adjustment)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("\(product.displayName) Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var combinedItems: [ProductActivityItem] {
        var items: [ProductActivityItem] = []
        
        for r in receivings {
            items.append(ProductActivityItem(
                id: "recv-\(r.id)",
                kind: .receiving,
                title: "Received \(r.quantity) units",
                subtitle: r.supplier?.name ?? r.invoiceNumber.map { "Invoice: \($0)" } ?? r.formattedDate,
                date: r.receivedAt,
                quantity: r.quantity,
                icon: "arrow.down.circle.fill",
                iconColor: .blue
            ))
        }
        
        for a in adjustments {
            let displayQty = a.type.isNegative ? -abs(a.quantity) : a.quantity
            items.append(ProductActivityItem(
                id: "adj-\(a.id)",
                kind: .adjustment(a.type),
                title: "\(a.type.displayName)",
                subtitle: a.reason ?? a.notes ?? a.adjustedAt.formatted(date: .abbreviated, time: .shortened),
                date: a.adjustedAt,
                quantity: displayQty,
                icon: a.type.icon,
                iconColor: a.type.isPositive ? .green : (a.type.isNegative ? .red : .orange)
            ))
        }
        
        return items.sorted { $0.date > $1.date }
    }
    
    @ViewBuilder
    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Activity Full Row (used in the full activity list)

struct ActivityFullRow: View {
    let item: ProductActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundColor(item.iconColor)
                .frame(width: 32, height: 32)
                .background(item.iconColor.opacity(0.12))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(item.quantityDisplay)
                .font(.headline)
                .foregroundColor(item.quantityColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Product Batch ViewModel (FIFO valuation + aging risk data)

@MainActor
class ProductBatchViewModel: ObservableObject {
    @Published var batches: [BatchValuation] = []
    @Published var productAging: ProductAgingAnalysis?
    @Published var isLoading = false
    
    struct AgingInfo {
        let fresh: Int   // < 30 days
        let moderate: Int // 30-90 days
        let old: Int     // > 90 days
    }
    
    var agingSummary: AgingInfo? {
        guard !batches.isEmpty else { return nil }
        let fresh = batches.filter { $0.age < 30 }.count
        let moderate = batches.filter { $0.age >= 30 && $0.age < 90 }.count
        let old = batches.filter { $0.age >= 90 }.count
        return AgingInfo(fresh: fresh, moderate: moderate, old: old)
    }
    
    /// Cash at risk: value of batches > 90 days old
    var cashAtRisk: Double {
        guard let aging = productAging else { return 0 }
        return aging.bucketDistribution
            .filter { ($0.bucket.min) >= 91 }
            .reduce(0) { $0 + $1.cashValue }
    }
    
    private let apiClient = APIClient.shared
    
    func loadBatches(productId: String, locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Guard against task cancellation to preserve existing data
        guard !Task.isCancelled else { return }
        
        // Load valuation and aging data in parallel
        async let valuationResult: () = loadValuation(productId: productId, locationId: locationId)
        async let agingResult: () = loadAgingAnalysis(productId: productId, locationId: locationId)
        _ = await (valuationResult, agingResult)
    }
    
    private func loadValuation(productId: String, locationId: String) async {
        do {
            let response: ValuationReportResponse = try await apiClient.request(
                endpoint: .valuationReport,
                queryParams: [
                    "locationId": locationId,
                    "productId": productId
                ]
            )
            // Extract batches from the product valuation
            if let productValuation = response.data.byProduct.first {
                batches = productValuation.batches ?? []
            } else {
                batches = []
            }
        } catch is CancellationError {
            // Request was cancelled (e.g. pull-to-refresh ended) — keep existing data
            return
        } catch {
            print("Failed to load batch valuation: \(error)")
            // Only clear if this is a fresh load (no existing data)
            // On refresh, keep stale data visible rather than showing empty state
        }
    }
    
    private func loadAgingAnalysis(productId: String, locationId: String) async {
        do {
            let response: ProductAgingResponse = try await apiClient.request(
                endpoint: .agingProducts,
                queryParams: [
                    "locationId": locationId,
                    "limit": "500"
                ]
            )
            // Find this product in the aging analysis
            productAging = response.products.first { $0.productId == productId }
        } catch is CancellationError {
            // Request was cancelled — keep existing data
            return
        } catch {
            // Silent fail — aging data is supplementary, keep existing data on refresh
            print("Failed to load aging analysis: \(error)")
        }
    }
}

// MARK: - Product Detail Response

struct ProductDetailResponse: Decodable {
    let success: Bool
    let data: Product
}

// MARK: - Edit Price View

struct EditPriceView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    var onUpdate: ((Product) -> Void)?
    
    @State private var priceText: String = ""
    @State private var syncToSquare = true
    @State private var applyToAllLocations = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var newPrice: Double? {
        Double(priceText.replacingOccurrences(of: ",", with: "."))
    }
    
    private var isValid: Bool {
        guard let price = newPrice, price > 0 else { return false }
        return true
    }
    
    private var priceChanged: Bool {
        guard let newPrice = newPrice else { return false }
        return newPrice != product.sellingPrice
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Current Price")
                        Spacer()
                        Text(product.formattedPrice ?? "Not set")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("New Price", text: $priceText)
                            .keyboardType(.decimalPad)
                        Text("MXN")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Selling Price")
                }
                
                if product.hasSquareSync == true {
                    Section {
                        Toggle("Update in Square", isOn: $syncToSquare)
                        
                        if syncToSquare {
                            Toggle("Apply to all locations", isOn: $applyToAllLocations)
                        }
                    } footer: {
                        if syncToSquare {
                            if applyToAllLocations {
                                Text("Price will be updated in Square POS at ALL locations immediately.")
                            } else {
                                Text("Price will be updated in Square POS for the current location only.")
                            }
                        } else {
                            Text("Price will only be updated locally. Square POS will show the old price.")
                        }
                    }
                }
                
                // Preview
                if let newPrice = newPrice, priceChanged {
                    Section {
                        HStack {
                            Text("Price Change")
                            Spacer()
                            let change = newPrice - (product.sellingPrice ?? 0)
                            Text(change >= 0 ? "+\(formatCurrency(change))" : formatCurrency(change))
                                .foregroundColor(change >= 0 ? .green : .red)
                        }
                        
                        if let cost = product.averageCost {
                            let newMargin = ((newPrice - cost) / newPrice) * 100
                            HStack {
                                Text("New Margin")
                                Spacer()
                                Text(String(format: "%.1f%%", newMargin))
                                    .foregroundColor(newMargin >= 20 ? .green : (newMargin >= 10 ? .orange : .red))
                            }
                        }
                    } header: {
                        Text("Preview")
                    }
                }
            }
            .navigationTitle("Edit Price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await updatePrice()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || !priceChanged || isSubmitting)
                }
            }
            .onAppear {
                if let price = product.sellingPrice {
                    priceText = String(format: "%.2f", price)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updatePrice() async {
        guard let price = newPrice,
              let locationId = authManager.currentLocation?.id else { return }
        
        isSubmitting = true
        
        do {
            let request = UpdatePriceRequest(
                sellingPrice: price,
                locationId: locationId,
                syncToSquare: syncToSquare,
                applyToAllLocations: syncToSquare ? applyToAllLocations : nil
            )
            
            let response: APIResponse<UpdatePriceResponse> = try await APIClient.shared.request(
                endpoint: .updateProductPrice(id: product.id),
                body: request
            )
            
            if let data = response.data {
                onUpdate?(data.product)
            }
            
            dismiss()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Failed to update price"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Cost & Supplier ViewModel

@MainActor
class CostSupplierViewModel: ObservableObject {
    @Published var suppliers: [ProductSupplier] = []
    @Published var costHistory: [SupplierCostHistoryGroup] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    func loadData(productId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Guard against task cancellation to preserve existing data
        guard !Task.isCancelled else { return }
        
        // Load both in parallel
        async let suppliersResult: () = loadSuppliers(productId: productId)
        async let costHistoryResult: () = loadCostHistory(productId: productId)
        _ = await (suppliersResult, costHistoryResult)
    }
    
    private func loadSuppliers(productId: String) async {
        do {
            let response: ProductSuppliersResponse = try await apiClient.request(
                endpoint: .productSuppliers(productId: productId)
            )
            suppliers = response.suppliers
        } catch is CancellationError {
            // Request was cancelled (e.g. pull-to-refresh ended) — keep existing data
            return
        } catch {
            print("Failed to load product suppliers: \(error)")
            // Keep existing data on refresh errors rather than clearing
        }
    }
    
    private func loadCostHistory(productId: String) async {
        do {
            let response: ProductCostHistoryResponse = try await apiClient.request(
                endpoint: .productCostHistory(productId: productId)
            )
            costHistory = response.suppliers
        } catch is CancellationError {
            // Request was cancelled — keep existing data
            return
        } catch {
            print("Failed to load product cost history: \(error)")
            // Keep existing data on refresh errors rather than clearing
        }
    }
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
