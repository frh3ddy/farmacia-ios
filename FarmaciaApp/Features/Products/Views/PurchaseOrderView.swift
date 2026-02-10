import SwiftUI

// MARK: - Purchase Order View (Shopping List)
// Flow: Select Supplier → See their product catalog → Set quantities → Review → Batch Receive

struct PurchaseOrderView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = PurchaseOrderViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .selectSupplier:
                    supplierSelectionStep
                case .buildOrder:
                    buildOrderStep
                case .review:
                    reviewStep
                case .submitting:
                    submittingStep
                case .complete:
                    completeStep
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.step == .selectSupplier {
                        Button("Cancel") { dismiss() }
                    } else if viewModel.step != .submitting && viewModel.step != .complete {
                        Button {
                            withAnimation { viewModel.goBack() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
    
    // MARK: - Step 1: Select Supplier
    
    private var supplierSelectionStep: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                Text("New Purchase Order")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Select a supplier to see their product catalog")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            
            if viewModel.isLoadingSuppliers {
                Spacer()
                ProgressView("Loading suppliers...")
                Spacer()
            } else if viewModel.suppliers.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No suppliers found")
                        .foregroundColor(.secondary)
                    Text("Suppliers are created when you receive inventory with a supplier selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredSuppliers) { supplier in
                        Button {
                            Task {
                                await viewModel.selectSupplier(supplier, locationId: authManager.currentLocation?.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    Text(String(supplier.name.prefix(1)).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplier.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    if let contact = supplier.contactInfo, !contact.isEmpty {
                                        Text(contact)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .searchable(text: $viewModel.supplierSearchText, prompt: "Search suppliers")
            }
        }
        .task {
            await viewModel.loadSuppliers()
        }
    }
    
    // MARK: - Step 2: Build Order (Product Catalog)
    
    private func catalogFilterLabel(_ filter: CatalogFilter) -> String {
        switch filter {
        case .all: return "All (\(viewModel.catalogItems.count))"
        case .needsRestock: return "Needs Restock (\(viewModel.needsRestockCount))"
        case .outOfStock: return "Out of Stock (\(viewModel.outOfStockCount))"
        case .inOrder: return "In Order (\(viewModel.orderItemCount))"
        }
    }
    
    private func lineItemPills(_ item: OrderLineItem) -> [String] {
        var pills: [String] = []
        if let lot = item.batchNumber, !lot.isEmpty {
            pills.append("Lot: \(lot)")
        }
        if let formatted = item.formattedExpiryDate {
            pills.append("Exp: \(formatted)")
        }
        return pills
    }
    
    private var buildOrderStep: some View {
        VStack(spacing: 0) {
            // Supplier header
            if let supplier = viewModel.selectedSupplier {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 36, height: 36)
                        Text(String(supplier.name.prefix(1)).uppercased())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supplier.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(viewModel.catalogItems.count) products available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if viewModel.orderItemCount > 0 {
                        Button {
                            withAnimation { viewModel.step = .review }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Review (\(viewModel.orderItemCount))")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
            }
            
            // Filter bar
            HStack(spacing: 8) {
                ForEach(CatalogFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.catalogFilter = filter
                        }
                    } label: {
                        Text(catalogFilterLabel(filter))
                            .font(.caption)
                            .fontWeight(viewModel.catalogFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(viewModel.catalogFilter == filter ? Color.blue.opacity(0.15) : Color(.systemGray5))
                            .foregroundColor(viewModel.catalogFilter == filter ? .blue : .primary)
                            .cornerRadius(12)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if viewModel.isLoadingCatalog {
                Spacer()
                ProgressView("Loading product catalog...")
                Spacer()
            } else if viewModel.filteredCatalogItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No products found")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(viewModel.filteredCatalogItems) { item in
                        CatalogItemRow(
                            item: item,
                            quantity: viewModel.orderQuantityBinding(for: item.productId),
                            unitCost: viewModel.orderCostBinding(for: item.productId),
                            batchNumber: viewModel.orderBatchNumberBinding(for: item.productId),
                            expiryDate: viewModel.orderExpiryDateBinding(for: item.productId)
                        )
                    }
                }
                .listStyle(.plain)
                .searchable(text: $viewModel.catalogSearchText, prompt: "Search products")
            }
        }
    }
    
    // MARK: - Step 3: Review Order
    
    private var reviewStep: some View {
        VStack(spacing: 0) {
            List {
                // Order summary header
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.selectedSupplier?.name ?? "Supplier")
                                .font(.headline)
                            Text("\(viewModel.orderItemCount) items")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.formattedOrderTotal)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                } header: {
                    Text("Order Summary")
                }
                
                // Invoice / notes
                Section {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        TextField("Invoice Number (optional)", text: $viewModel.invoiceNumber)
                    }
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                        TextField("Notes (optional)", text: $viewModel.orderNotes)
                    }
                } header: {
                    Text("Details")
                }
                
                // Line items
                Section {
                    ForEach(viewModel.orderLineItems) { lineItem in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lineItem.productName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let sku = lineItem.sku {
                                        Text("SKU: \(sku)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(lineItem.quantity) × \(lineItem.formattedUnitCost)")
                                        .font(.subheadline)
                                    Text(lineItem.formattedLineTotal)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Batch metadata pills
                            let pills = lineItemPills(lineItem)
                            if !pills.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(pills, id: \.self) { pill in
                                        Text(pill)
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        viewModel.removeLineItems(at: indexSet)
                    }
                } header: {
                    Text("Items (\(viewModel.orderItemCount))")
                }
            }
            
            // Submit button
            Button {
                Task {
                    await viewModel.submitOrder(locationId: authManager.currentLocation?.id, receivedBy: authManager.currentEmployee?.id)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc.fill")
                    Text("Receive \(viewModel.orderItemCount) Items")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding()
        }
    }
    
    // MARK: - Step 4: Submitting
    
    private var submittingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Receiving inventory...")
                .font(.headline)
            
            Text("Processing \(viewModel.submittedCount) of \(viewModel.orderItemCount) items")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress bar
            ProgressView(value: Double(viewModel.submittedCount), total: Double(viewModel.orderItemCount))
                .progressViewStyle(.linear)
                .padding(.horizontal, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Step 5: Complete
    
    private var completeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Order Received!")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("\(viewModel.submittedCount) items received successfully")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if viewModel.failedCount > 0 {
                    Text("\(viewModel.failedCount) items failed")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                Text("Total: \(viewModel.formattedOrderTotal)")
                    .font(.headline)
            }
            
            if !viewModel.failedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Failed Items:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(viewModel.failedItems, id: \.productName) { item in
                        Text("• \(item.productName): \(item.error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding()
        }
    }
}

// MARK: - Catalog Filter

enum CatalogFilter: CaseIterable {
    case all, needsRestock, outOfStock, inOrder
    
    var title: String {
        switch self {
        case .all: return "All"
        case .needsRestock: return "Needs Restock"
        case .outOfStock: return "Out of Stock"
        case .inOrder: return "In Order"
        }
    }
}

// MARK: - Catalog Item Row

struct CatalogItemRow: View {
    let item: SupplierCatalogItem
    @Binding var quantity: String
    @Binding var unitCost: String
    @Binding var batchNumber: String
    @Binding var expiryDate: Date?
    
    @State private var isExpanded = false
    @State private var hasExpiry = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(spacing: 12) {
                // Product image or placeholder
                if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        productPlaceholder
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(8)
                    .clipped()
                } else {
                    productPlaceholder
                }
                
                // Product info
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        if let sku = item.sku {
                            Text(sku)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        // Stock badge
                        stockBadge
                    }
                }
                
                Spacer()
                
                // Cost and quantity
                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.formattedCost)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Quick quantity input
                    HStack(spacing: 6) {
                        Button {
                            let current = Int(quantity) ?? 0
                            if current > 0 {
                                quantity = "\(current - 1)"
                                if current - 1 == 0 { quantity = "" }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(quantity.isEmpty ? .gray : .red)
                        }
                        .buttonStyle(.plain)
                        .disabled(quantity.isEmpty)
                        
                        TextField("0", text: $quantity)
                            .keyboardType(.numberPad)
                            .frame(width: 44)
                            .multilineTextAlignment(.center)
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(quantity.isEmpty ? Color(.systemGray6) : Color.blue.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(quantity.isEmpty ? Color.clear : Color.blue, lineWidth: 1)
                            )
                        
                        Button {
                            let current = Int(quantity) ?? 0
                            quantity = "\(current + 1)"
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Expanded: custom cost override + batch/expiry
            if isExpanded && !(quantity.isEmpty || quantity == "0") {
                VStack(spacing: 8) {
                    HStack {
                        Text("Unit Cost:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Cost", text: $unitCost)
                            .keyboardType(.decimalPad)
                            .font(.caption)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        if let qty = Int(quantity), let cost = Double(unitCost), qty > 0 {
                            Text("Line: \(String(format: "$%.2f", Double(qty) * cost))")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Batch number
                    HStack {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .frame(width: 16)
                        TextField("Lot / Batch # (optional)", text: $batchNumber)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                    
                    // Expiry date toggle + picker
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Toggle("Expiry Date", isOn: $hasExpiry)
                            .font(.caption)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                    
                    if hasExpiry {
                        DatePicker(
                            "Expires",
                            selection: Binding(
                                get: { expiryDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60) },
                                set: { expiryDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .font(.caption)
                        .datePickerStyle(.compact)
                    }
                }
                .padding(.leading, 56)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !(quantity.isEmpty || quantity == "0") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }
        }
        .onChange(of: quantity) { newValue in
            // Auto-fill cost from last cost when quantity first entered
            if !newValue.isEmpty && newValue != "0" && unitCost.isEmpty {
                unitCost = item.lastCost
            }
            // Expand to show cost when adding quantity
            if !newValue.isEmpty && newValue != "0" && !isExpanded {
                withAnimation { isExpanded = true }
            }
            if newValue.isEmpty || newValue == "0" {
                isExpanded = false
                hasExpiry = false
                expiryDate = nil
                batchNumber = ""
            }
        }
        .onChange(of: hasExpiry) { newValue in
            if !newValue {
                expiryDate = nil
            } else if expiryDate == nil {
                expiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
            }
        }
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 44)
            Image(systemName: "pills.fill")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
    
    private var stockBadge: some View {
        Group {
            if item.isOutOfStock {
                Text("OUT")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            } else if item.isLowStock {
                Text("LOW \(item.currentStock)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            } else {
                Text("\(item.currentStock) in stock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Order Line Item

struct OrderLineItem: Identifiable {
    let productId: String
    let productName: String
    let sku: String?
    let quantity: Int
    let unitCost: Double
    let batchNumber: String?
    let expiryDate: Date?
    
    var id: String { productId }
    
    var lineTotal: Double { Double(quantity) * unitCost }
    
    var formattedUnitCost: String {
        String(format: "$%.2f", unitCost)
    }
    
    var formattedLineTotal: String {
        String(format: "$%.2f", lineTotal)
    }
    
    var formattedExpiryDate: String? {
        guard let date = expiryDate else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Failed Item

struct FailedOrderItem {
    let productName: String
    let error: String
}

// MARK: - Purchase Order Step

enum PurchaseOrderStep {
    case selectSupplier
    case buildOrder
    case review
    case submitting
    case complete
}

// MARK: - Purchase Order ViewModel

@MainActor
class PurchaseOrderViewModel: ObservableObject {
    @Published var step: PurchaseOrderStep = .selectSupplier
    
    // Supplier selection
    @Published var suppliers: [Supplier] = []
    @Published var isLoadingSuppliers = false
    @Published var supplierSearchText = ""
    @Published var selectedSupplier: Supplier?
    
    // Catalog
    @Published var catalogItems: [SupplierCatalogItem] = []
    @Published var isLoadingCatalog = false
    @Published var catalogSearchText = ""
    @Published var catalogFilter: CatalogFilter = .all
    
    // Order quantities and costs: productId → (quantity string, cost string)
    @Published var orderQuantities: [String: String] = [:]
    @Published var orderCosts: [String: String] = [:]
    @Published var orderBatchNumbers: [String: String] = [:]
    @Published var orderExpiryDates: [String: Date] = [:]
    
    // Order details
    @Published var invoiceNumber = ""
    @Published var orderNotes = ""
    
    // Submission state
    @Published var submittedCount = 0
    @Published var failedCount = 0
    @Published var failedItems: [FailedOrderItem] = []
    
    // Error
    @Published var showError = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    // MARK: - Computed Properties
    
    var navigationTitle: String {
        switch step {
        case .selectSupplier: return "Purchase Order"
        case .buildOrder: return "Product Catalog"
        case .review: return "Review Order"
        case .submitting: return "Receiving..."
        case .complete: return "Complete"
        }
    }
    
    var filteredSuppliers: [Supplier] {
        if supplierSearchText.isEmpty { return suppliers }
        let query = supplierSearchText.lowercased()
        return suppliers.filter { $0.name.lowercased().contains(query) }
    }
    
    var filteredCatalogItems: [SupplierCatalogItem] {
        var items = catalogItems
        
        // Apply filter
        switch catalogFilter {
        case .all: break
        case .needsRestock:
            items = items.filter { $0.isLowStock || $0.isOutOfStock }
        case .outOfStock:
            items = items.filter { $0.isOutOfStock }
        case .inOrder:
            items = items.filter { isInOrder($0.productId) }
        }
        
        // Apply search
        if !catalogSearchText.isEmpty {
            let query = catalogSearchText.lowercased()
            items = items.filter {
                $0.productName.lowercased().contains(query) ||
                ($0.sku?.lowercased().contains(query) ?? false)
            }
        }
        
        return items
    }
    
    var orderItemCount: Int {
        orderQuantities.values.filter { qty in
            guard let q = Int(qty), q > 0 else { return false }
            return true
        }.count
    }
    
    var needsRestockCount: Int {
        catalogItems.filter { $0.isLowStock || $0.isOutOfStock }.count
    }
    
    var outOfStockCount: Int {
        catalogItems.filter { $0.isOutOfStock }.count
    }
    
    var orderLineItems: [OrderLineItem] {
        catalogItems.compactMap { item in
            guard let qtyStr = orderQuantities[item.productId],
                  let qty = Int(qtyStr), qty > 0 else { return nil }
            let cost = Double(orderCosts[item.productId] ?? item.lastCost) ?? item.lastCostDouble
            let batchNum = orderBatchNumbers[item.productId]
            let expiry = orderExpiryDates[item.productId]
            return OrderLineItem(
                productId: item.productId,
                productName: item.productName,
                sku: item.sku,
                quantity: qty,
                unitCost: cost,
                batchNumber: batchNum?.isEmpty == true ? nil : batchNum,
                expiryDate: expiry
            )
        }
    }
    
    var orderTotal: Double {
        orderLineItems.reduce(0) { $0 + $1.lineTotal }
    }
    
    var formattedOrderTotal: String {
        String(format: "$%.2f", orderTotal)
    }
    
    // MARK: - Bindings
    
    func orderQuantityBinding(for productId: String) -> Binding<String> {
        Binding(
            get: { self.orderQuantities[productId] ?? "" },
            set: { self.orderQuantities[productId] = $0 }
        )
    }
    
    func orderCostBinding(for productId: String) -> Binding<String> {
        Binding(
            get: { self.orderCosts[productId] ?? "" },
            set: { self.orderCosts[productId] = $0 }
        )
    }
    
    func orderBatchNumberBinding(for productId: String) -> Binding<String> {
        Binding(
            get: { self.orderBatchNumbers[productId] ?? "" },
            set: { self.orderBatchNumbers[productId] = $0 }
        )
    }
    
    func orderExpiryDateBinding(for productId: String) -> Binding<Date?> {
        Binding(
            get: { self.orderExpiryDates[productId] },
            set: { self.orderExpiryDates[productId] = $0 }
        )
    }
    
    // MARK: - Actions
    
    func loadSuppliers() async {
        isLoadingSuppliers = true
        defer { isLoadingSuppliers = false }
        
        do {
            let response: SupplierListResponse = try await apiClient.request(
                endpoint: .listSuppliers
            )
            suppliers = response.data.filter { $0.isActive ?? true }
        } catch {
            print("Failed to load suppliers: \(error)")
            suppliers = []
        }
    }
    
    func selectSupplier(_ supplier: Supplier, locationId: String?) async {
        selectedSupplier = supplier
        isLoadingCatalog = true
        
        withAnimation { step = .buildOrder }
        
        defer { isLoadingCatalog = false }
        
        do {
            var queryParams: [String: String] = [:]
            if let locationId = locationId {
                queryParams["locationId"] = locationId
            }
            
            let response: SupplierCatalogResponse = try await apiClient.request(
                endpoint: .supplierCatalog(supplierId: supplier.id),
                queryParams: queryParams
            )
            catalogItems = response.products
        } catch {
            print("Failed to load supplier catalog: \(error)")
            catalogItems = []
            errorMessage = "Failed to load product catalog"
            showError = true
        }
    }
    
    func goBack() {
        switch step {
        case .buildOrder:
            step = .selectSupplier
            selectedSupplier = nil
            catalogItems = []
            orderQuantities = [:]
            orderCosts = [:]
            orderBatchNumbers = [:]
            orderExpiryDates = [:]
            catalogSearchText = ""
            catalogFilter = .all
        case .review:
            step = .buildOrder
        default:
            break
        }
    }
    
    func removeLineItems(at offsets: IndexSet) {
        let items = orderLineItems
        for index in offsets {
            let item = items[index]
            orderQuantities[item.productId] = nil
            orderCosts[item.productId] = nil
            orderBatchNumbers[item.productId] = nil
            orderExpiryDates[item.productId] = nil
        }
        // If no items left, go back to build
        if orderItemCount == 0 {
            withAnimation { step = .buildOrder }
        }
    }
    
    func isInOrder(_ productId: String) -> Bool {
        guard let qty = orderQuantities[productId], let q = Int(qty) else { return false }
        return q > 0
    }
    
    func submitOrder(locationId: String?, receivedBy: String?) async {
        guard let locationId = locationId else {
            errorMessage = "No location selected"
            showError = true
            return
        }
        
        guard let supplierId = selectedSupplier?.id else {
            errorMessage = "No supplier selected"
            showError = true
            return
        }
        
        let lineItems = orderLineItems
        guard !lineItems.isEmpty else {
            errorMessage = "No items in order"
            showError = true
            return
        }
        
        withAnimation { step = .submitting }
        submittedCount = 0
        failedCount = 0
        failedItems = []
        
        // Date formatter for expiry dates (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Submit each line item as a separate receiving
        for lineItem in lineItems {
            do {
                let expiryDateString = lineItem.expiryDate.map { dateFormatter.string(from: $0) }
                
                let request = ReceiveInventoryRequest(
                    locationId: locationId,
                    productId: lineItem.productId,
                    quantity: lineItem.quantity,
                    unitCost: lineItem.unitCost,
                    supplierId: supplierId,
                    invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
                    purchaseOrderId: nil,
                    batchNumber: lineItem.batchNumber,
                    expiryDate: expiryDateString,
                    manufacturingDate: nil,
                    receivedBy: receivedBy,
                    notes: orderNotes.isEmpty ? nil : "Purchase Order: \(orderNotes)",
                    syncToSquare: true,
                    sellingPrice: nil,
                    syncPriceToSquare: nil
                )
                
                let _: ReceivingCreateResponse = try await apiClient.request(
                    endpoint: .receiveInventory,
                    body: request
                )
                
                submittedCount += 1
            } catch {
                failedCount += 1
                failedItems.append(FailedOrderItem(
                    productName: lineItem.productName,
                    error: error.localizedDescription
                ))
            }
        }
        
        withAnimation { step = .complete }
    }
}

// MARK: - Preview

#Preview {
    PurchaseOrderView()
        .environmentObject(AuthManager.shared)
}
