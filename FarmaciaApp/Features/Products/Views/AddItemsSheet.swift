import SwiftUI

// MARK: - Add Items Sheet
// Three ways to add items to a shopping list:
// 1. Search all products (default — supplier-agnostic)
// 2. Browse supplier catalog (when supplier is assigned)
// 3. Bulk-add all out-of-stock or low-stock items
//
// Phase C enhancements:
// - Supplier catalog tab shows supplier cost vs average cost comparison
// - Smart quantity suggestions based on stock levels

struct AddItemsSheet: View {
    let listId: UUID
    @ObservedObject var store: ShoppingListStore
    let supplierId: String?
    let locationId: String?
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var products: [Product] = []
    @State private var catalogItems: [SupplierCatalogItem] = []
    @State private var isLoading = false
    @State private var selectedTab: AddItemTab = .allProducts
    @State private var addedProductIds: Set<String> = []
    @State private var quantities: [String: String] = [:]    // productId → qty string
    @State private var showBulkConfirm = false
    @State private var bulkType: BulkAddType = .outOfStock
    
    private let apiClient = APIClient.shared
    
    enum AddItemTab: String, CaseIterable {
        case allProducts = "Todos los Productos"
        case supplierCatalog = "Catálogo de Proveedor"
    }
    
    enum BulkAddType {
        case outOfStock, lowStock
        
        var label: String {
            switch self {
            case .outOfStock: return "out of stock"
            case .lowStock: return "low stock"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker (only show supplier tab if supplier assigned)
                if supplierId != nil {
                    Picker("Fuente", selection: $selectedTab) {
                        ForEach(AddItemTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Bulk add buttons
                bulkAddBar
                
                // Content
                Group {
                    if isLoading {
                        Spacer()
                        ProgressView("Cargando productos...")
                        Spacer()
                    } else if selectedTab == .allProducts {
                        allProductsList
                    } else {
                        supplierCatalogList
                    }
                }
            }
            .navigationTitle("Agregar Artículos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Listo") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !addedProductIds.isEmpty {
                        Text("\(addedProductIds.count) added")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar productos...")
            .task {
                await loadProducts()
                if supplierId != nil {
                    await loadCatalog()
                }
                // Pre-fill already-in-list product IDs
                if let list = store.list(for: listId) {
                    addedProductIds = Set(list.items.map(\.productId))
                }
                // Pre-fill smart quantity suggestions
                prefillSuggestedQuantities()
            }
            .alert("Agregar Todo", isPresented: $showBulkConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Agregar Todo") {
                    performBulkAdd()
                }
            } message: {
                Text("Add all \(bulkItems.count) \(bulkType.label) items to this shopping list?")
            }
        }
    }
    
    // MARK: - Bulk Add Bar
    
    private var bulkAddBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let outOfStockCount = products.filter { ($0.totalInventory ?? 0) == 0 }.count
                let lowStockCount = products.filter { let inv = $0.totalInventory ?? 0; return inv > 0 && inv < 10 }.count
                
                if outOfStockCount > 0 {
                    Button {
                        bulkType = .outOfStock
                        showBulkConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                            Text("Add \(outOfStockCount) Out of Stock")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(16)
                    }
                }
                
                if lowStockCount > 0 {
                    Button {
                        bulkType = .lowStock
                        showBulkConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Add \(lowStockCount) Low Stock")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(16)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
    
    private var bulkItems: [Product] {
        switch bulkType {
        case .outOfStock:
            return products.filter { ($0.totalInventory ?? 0) == 0 }
        case .lowStock:
            return products.filter { let inv = $0.totalInventory ?? 0; return inv > 0 && inv < 10 }
        }
    }
    
    private func performBulkAdd() {
        for product in bulkItems where !addedProductIds.contains(product.id) {
            let suggestedQty = suggestedQuantity(for: product)
            let supplierCost = supplierCostForProduct(product.id)
            let costToUse = supplierCost ?? product.averageCost ?? 0
            let item = ShoppingListItem(
                productId: product.id,
                productName: product.displayName,
                sku: product.sku,
                plannedQuantity: suggestedQty,
                unitCost: costToUse,
                previousCost: product.averageCost
            )
            store.addItem(to: listId, item: item)
            addedProductIds.insert(product.id)
        }
    }
    
    // MARK: - Smart Quantity Suggestions
    
    /// Suggests a reorder quantity based on stock level.
    /// Out-of-stock: suggest 10 (typical reorder), low stock: suggest enough to reach 10.
    private func suggestedQuantity(for product: Product) -> Int {
        let stock = product.totalInventory ?? 0
        let reorderTarget = 10
        if stock == 0 {
            return reorderTarget // Suggest a reasonable reorder for OOS
        } else if stock < reorderTarget {
            return reorderTarget - stock // Bring up to target
        }
        return 1
    }
    
    /// Pre-fills the quantity text fields with smart suggestions for OOS and low-stock items
    private func prefillSuggestedQuantities() {
        for product in products {
            let stock = product.totalInventory ?? 0
            if stock < 10 && quantities[product.id] == nil {
                let suggested = suggestedQuantity(for: product)
                if suggested > 1 {
                    quantities[product.id] = "\(suggested)"
                }
            }
        }
    }
    
    /// Look up supplier-specific cost for a product (from catalog data)
    private func supplierCostForProduct(_ productId: String) -> Double? {
        catalogItems.first(where: { $0.productId == productId })?.lastCostDouble
    }
    
    // MARK: - All Products List
    
    private var allProductsList: some View {
        let filtered = filteredProducts
        
        return Group {
            if filtered.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No products match \"\(searchText)\"")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filtered) { product in
                        let supplierCost = supplierCostForProduct(product.id)
                        AddProductRow(
                            productId: product.id,
                            name: product.displayName,
                            sku: product.sku,
                            currentStock: product.totalInventory ?? 0,
                            averageCost: product.averageCost ?? 0,
                            supplierCost: supplierCost,
                            isAdded: addedProductIds.contains(product.id),
                            quantity: bindingForQuantity(product.id),
                            onAdd: {
                                addProduct(product)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty { return products }
        let query = searchText.lowercased()
        return products.filter {
            $0.displayName.lowercased().contains(query) ||
            ($0.sku?.lowercased().contains(query) ?? false)
        }
    }
    
    private func addProduct(_ product: Product) {
        let qty = Int(quantities[product.id] ?? "") ?? suggestedQuantity(for: product)
        // When supplier is assigned and catalog has a cost, use supplier cost; otherwise use average cost
        let supplierCost = supplierCostForProduct(product.id)
        let costToUse = supplierCost ?? product.averageCost ?? 0
        let item = ShoppingListItem(
            productId: product.id,
            productName: product.displayName,
            sku: product.sku,
            plannedQuantity: max(1, qty),
            unitCost: costToUse,
            previousCost: product.averageCost
        )
        store.addItem(to: listId, item: item)
        addedProductIds.insert(product.id)
    }
    
    // MARK: - Supplier Catalog List
    
    private var supplierCatalogList: some View {
        let filtered = filteredCatalogItems
        
        return Group {
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No catalog items found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filtered) { item in
                        let matchingProduct = products.first(where: { $0.id == item.productId })
                        let avgCost = matchingProduct?.averageCost ?? 0
                        AddProductRow(
                            productId: item.productId,
                            name: item.productName,
                            sku: item.sku,
                            currentStock: item.currentStock,
                            averageCost: avgCost,
                            supplierCost: item.lastCostDouble,
                            isAdded: addedProductIds.contains(item.productId),
                            quantity: bindingForQuantity(item.productId),
                            onAdd: {
                                addCatalogItem(item, averageCost: avgCost)
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var filteredCatalogItems: [SupplierCatalogItem] {
        if searchText.isEmpty { return catalogItems }
        let query = searchText.lowercased()
        return catalogItems.filter {
            $0.productName.lowercased().contains(query) ||
            ($0.sku?.lowercased().contains(query) ?? false)
        }
    }
    
    private func addCatalogItem(_ item: SupplierCatalogItem, averageCost: Double) {
        let matchingProduct = products.first(where: { $0.id == item.productId })
        let qty: Int
        if let qtyStr = quantities[item.productId], let parsed = Int(qtyStr), parsed > 0 {
            qty = parsed
        } else if let product = matchingProduct {
            qty = suggestedQuantity(for: product)
        } else {
            qty = 1
        }
        let listItem = ShoppingListItem(
            productId: item.productId,
            productName: item.productName,
            sku: item.sku,
            plannedQuantity: max(1, qty),
            unitCost: item.lastCostDouble,
            previousCost: averageCost > 0 ? averageCost : nil
        )
        store.addItem(to: listId, item: listItem)
        addedProductIds.insert(item.productId)
    }
    
    // MARK: - Helpers
    
    private func bindingForQuantity(_ productId: String) -> Binding<String> {
        Binding(
            get: { quantities[productId] ?? "" },
            set: { quantities[productId] = $0 }
        )
    }
    
    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            var queryParams: [String: String] = [:]
            if let locationId = locationId {
                queryParams["locationId"] = locationId
            }
            
            let response: ProductListResponse = try await apiClient.request(
                endpoint: .listProducts,
                queryParams: queryParams
            )
            products = response.data
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    private func loadCatalog() async {
        guard let supplierId = supplierId else { return }
        
        do {
            var queryParams: [String: String] = [:]
            if let locationId = locationId {
                queryParams["locationId"] = locationId
            }
            
            let response: SupplierCatalogResponse = try await apiClient.request(
                endpoint: .supplierCatalog(supplierId: supplierId),
                queryParams: queryParams
            )
            catalogItems = response.products
        } catch {
            print("Failed to load supplier catalog: \(error)")
        }
    }
}

// MARK: - Add Product Row (Phase C: supplier cost comparison)

struct AddProductRow: View {
    let productId: String
    let name: String
    let sku: String?
    let currentStock: Int
    let averageCost: Double
    let supplierCost: Double?       // Supplier-specific price (nil if no supplier assigned)
    let isAdded: Bool
    @Binding var quantity: String
    var onAdd: () -> Void
    
    /// The cost to display prominently (supplier cost if available, otherwise average)
    private var displayCost: Double {
        supplierCost ?? averageCost
    }
    
    /// Cost comparison info between supplier cost and average cost
    private var costComparison: CostComparisonInfo? {
        guard let sCost = supplierCost, averageCost > 0 else { return nil }
        let diff = sCost - averageCost
        guard abs(diff) > 0.001 else { return nil }
        let pct = (diff / averageCost) * 100
        return CostComparisonInfo(
            supplierCost: sCost,
            averageCost: averageCost,
            difference: diff,
            percentChange: pct,
            isHigher: diff > 0
        )
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Product info
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    if let sku = sku {
                        Text(sku)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    stockBadge
                    
                    // Primary cost display
                    Text(String(format: "$%.2f", displayCost))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Cost comparison indicator (Phase C)
                if let comparison = costComparison {
                    CostComparisonBadge(info: comparison)
                }
            }
            
            Spacer()
            
            if isAdded {
                // Already added indicator
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Added")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                // Quantity input + add button
                HStack(spacing: 6) {
                    TextField("1", text: $quantity)
                        .keyboardType(.numberPad)
                        .frame(width: 36)
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    
                    Button {
                        onAdd()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private var stockBadge: some View {
        Group {
            if currentStock == 0 {
                Text("OUT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            } else if currentStock < 10 {
                Text("LOW \(currentStock)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            } else {
                Text("\(currentStock)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Cost Comparison Info

struct CostComparisonInfo {
    let supplierCost: Double
    let averageCost: Double
    let difference: Double
    let percentChange: Double
    let isHigher: Bool
    
    var arrow: String { isHigher ? "↑" : "↓" }
    var color: Color { isHigher ? .red : .green }
    
    var summary: String {
        String(format: "%@ %+.0f%% vs avg $%.2f", arrow, percentChange, averageCost)
    }
}

// MARK: - Cost Comparison Badge

struct CostComparisonBadge: View {
    let info: CostComparisonInfo
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: info.isHigher ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8, weight: .bold))
            Text(info.summary)
                .font(.system(size: 9))
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(info.color.opacity(0.1))
        .foregroundColor(info.color)
        .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    AddItemsSheet(
        listId: UUID(),
        store: ShoppingListStore.shared,
        supplierId: nil,
        locationId: nil
    )
}
