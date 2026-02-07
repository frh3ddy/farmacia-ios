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
    
    // Batch section expansion state
    @State private var showAllBatches = false
    
    // Shared inventory view model for forms
    @StateObject private var inventoryViewModel = InventoryViewModel()
    
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
                        await loadActivity()
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
                        await loadActivity()
                    }
                }
            )
        }
        .task {
            // Load suppliers for receive form
            await inventoryViewModel.loadProducts()
            await inventoryViewModel.loadSuppliers()
            // Load product-scoped activity and batch data in parallel
            async let activityLoad: () = loadActivity()
            async let batchLoad: () = loadBatchData()
            _ = await (activityLoad, batchLoad)
        }
        .refreshable {
            await refreshProduct()
            async let activityLoad: () = loadActivity()
            async let batchLoad: () = loadBatchData()
            _ = await (activityLoad, batchLoad)
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
    }
    
    // MARK: - Product Header
    
    private var productHeader: some View {
        VStack(spacing: 12) {
            // Product Image or Placeholder
            if let imageUrl = displayProduct.squareImageUrl, let url = URL(string: imageUrl) {
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
            } else {
                productPlaceholder
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
    
    private func loadBatchData() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await batchViewModel.loadBatches(
            productId: displayProduct.id,
            locationId: locationId
        )
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
                // Batch summary bar
                if let agingInfo = batchViewModel.agingSummary {
                    HStack(spacing: 12) {
                        agingPill(label: "<30d", count: agingInfo.fresh, color: .green)
                        agingPill(label: "30-90d", count: agingInfo.moderate, color: .orange)
                        agingPill(label: ">90d", count: agingInfo.old, color: .red)
                    }
                }
                
                // Individual batches (show first 3, expand for all)
                let batchesToShow = showAllBatches ? batchViewModel.batches : Array(batchViewModel.batches.prefix(3))
                ForEach(batchesToShow) { batch in
                    batchRow(batch)
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
        HStack(spacing: 10) {
            // Age indicator
            Circle()
                .fill(batchAgeColor(batch.age))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("\(batch.quantity) units")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("@ $\(batch.unitCost)/ea")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("\(batch.age) days old \u{2022} \(batch.receivedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Batch value
            Text("$\(batch.value)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
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
            }
            
            Divider()
            
            let receivings = activityViewModel.receivings
            
            if receivings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No purchase history yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                // Cost trend summary
                if let latestCost = receivings.first?.unitCostDouble,
                   let oldestCost = receivings.last?.unitCostDouble,
                   receivings.count > 1 {
                    let change = latestCost - oldestCost
                    let changePercent = oldestCost > 0 ? (change / oldestCost) * 100 : 0
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest Cost")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", latestCost))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Trend")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption)
                                Text(String(format: "%.1f%%", abs(changePercent)))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(change > 0 ? .red : .green)
                        }
                    }
                    .padding(.bottom, 4)
                }
                
                // Supplier breakdown
                let supplierGroups = Dictionary(grouping: receivings.filter { $0.supplier != nil }) { $0.supplier!.name }
                if !supplierGroups.isEmpty {
                    Text("Suppliers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(Array(supplierGroups.keys.sorted()), id: \.self) { supplierName in
                        if let items = supplierGroups[supplierName] {
                            let totalQty = items.reduce(0) { $0 + $1.quantity }
                            let avgCost = items.reduce(0.0) { $0 + $1.unitCostDouble } / Double(items.count)
                            let lastDate = items.map { $0.receivedAt }.max() ?? Date()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplierName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(items.count) orders \u{2022} \(totalQty) units")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "Avg $%.2f", avgCost))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("Last: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                            
                            if supplierName != supplierGroups.keys.sorted().last {
                                Divider()
                            }
                        }
                    }
                }
                
                // Recent cost entries (mini timeline)
                if receivings.count > 0 {
                    Divider()
                    Text("Recent Costs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(receivings.prefix(5)) { r in
                        HStack {
                            Text(r.receivedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(String(format: "$%.2f", r.unitCostDouble))
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text("\u{00D7}\(r.quantity)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let supplier = r.supplier?.name {
                                Text(supplier)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
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

// MARK: - Product Batch ViewModel (FIFO valuation data)

@MainActor
class ProductBatchViewModel: ObservableObject {
    @Published var batches: [BatchValuation] = []
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
    
    private let apiClient = APIClient.shared
    
    func loadBatches(productId: String, locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
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
        } catch {
            // Silent fail — batch data is supplementary
            print("Failed to load batch valuation: \(error)")
            batches = []
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
