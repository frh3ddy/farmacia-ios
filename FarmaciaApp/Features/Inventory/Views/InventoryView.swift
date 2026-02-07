import SwiftUI

// MARK: - Inventory View

struct InventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedSegment: InventorySegment = .receive
    
    enum InventorySegment: String, CaseIterable {
        case receive = "Receive"
        case adjustments = "Adjustments"
        case history = "History"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Inventory", selection: $selectedSegment) {
                    ForEach(InventorySegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on segment
                switch selectedSegment {
                case .receive:
                    if authManager.canManageInventory {
                        ReceiveInventoryView()
                    } else {
                        noPermissionView
                    }
                case .adjustments:
                    if authManager.canManageInventory {
                        AdjustmentsListView()
                    } else {
                        noPermissionView
                    }
                case .history:
                    ReceivingHistoryView()
                }
            }
            .navigationTitle("Inventory")
        }
    }
    
    private var noPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Access Restricted")
                .font(.headline)
            
            Text("You don't have permission to access this feature.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Inventory ViewModel

@MainActor
class InventoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var suppliers: [Supplier] = []
    @Published var recentReceivings: [InventoryReceiving] = []
    @Published var recentAdjustments: [InventoryAdjustment] = []
    
    @Published var isLoadingProducts = false
    @Published var isLoadingReceivings = false
    @Published var isLoadingAdjustments = false
    @Published var isSubmitting = false
    
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var successMessage: String?
    @Published var showSuccess = false
    
    // MARK: - Dependencies
    private let apiClient = APIClient.shared
    
    // MARK: - Date Formatter (for date-only fields)
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            let response: ProductListResponse = try await apiClient.request(endpoint: .listProducts)
            products = response.data
        } catch is CancellationError {
            // Request was cancelled, don't show error
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            if error.localizedDescription.lowercased().contains("cancel") {
                return
            }
            errorMessage = "Failed to load products"
            showError = true
        }
    }
    
    // MARK: - Load Suppliers
    func loadSuppliers() async {
        do {
            let response: SupplierListResponse = try await apiClient.request(endpoint: .listSuppliers)
            suppliers = response.data
        } catch {
            // Suppliers are optional, don't show error
            print("Failed to load suppliers: \(error)")
        }
    }
    
    // MARK: - Load Receivings
    func loadReceivings(locationId: String) async {
        isLoadingReceivings = true
        defer { isLoadingReceivings = false }
        
        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByLocation(locationId: locationId)
            )
            recentReceivings = response.data
        } catch is CancellationError {
            // Request was cancelled, don't show error
            return
        } catch let error as NetworkError {
            // Don't show cancelled errors
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            // Don't show cancelled errors
            if error.localizedDescription.lowercased().contains("cancel") {
                return
            }
            errorMessage = "Failed to load receivings"
            showError = true
        }
    }
    
    // MARK: - Load Adjustments
    func loadAdjustments(locationId: String) async {
        isLoadingAdjustments = true
        defer { isLoadingAdjustments = false }
        
        do {
            let response: AdjustmentListResponse = try await apiClient.request(
                endpoint: .adjustmentsByLocation(locationId: locationId)
            )
            recentAdjustments = response.data
        } catch is CancellationError {
            // Request was cancelled, don't show error
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") == true {
                return
            }
            errorMessage = error.errorDescription
            showError = true
        } catch {
            if error.localizedDescription.lowercased().contains("cancel") {
                return
            }
            errorMessage = "Failed to load adjustments"
            showError = true
        }
    }
    
    // MARK: - Receive Inventory
    func receiveInventory(
        productId: String,
        quantity: Int,
        unitCost: Double,
        locationId: String,
        supplierId: String?,
        invoiceNumber: String?,
        batchNumber: String?,
        expiryDate: Date?,
        notes: String?,
        sellingPrice: Double? = nil,
        syncPriceToSquare: Bool = true
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        
        // Format date as YYYY-MM-DD string to avoid timezone issues
        let expiryDateString = expiryDate.map { Self.dateOnlyFormatter.string(from: $0) }
        
        let request = ReceiveInventoryRequest(
            locationId: locationId,
            productId: productId,
            quantity: quantity,
            unitCost: unitCost,
            supplierId: supplierId,
            invoiceNumber: invoiceNumber?.isEmpty == true ? nil : invoiceNumber,
            purchaseOrderId: nil,
            batchNumber: batchNumber?.isEmpty == true ? nil : batchNumber,
            expiryDate: expiryDateString,
            manufacturingDate: nil,
            receivedBy: nil,
            notes: notes?.isEmpty == true ? nil : notes,
            syncToSquare: true,
            sellingPrice: sellingPrice,
            syncPriceToSquare: sellingPrice != nil ? syncPriceToSquare : nil
        )
        
        do {
            let response: ReceivingCreateResponse = try await apiClient.request(
                endpoint: .receiveInventory,
                body: request
            )
            successMessage = response.message
            showSuccess = true
            
            // Reload receivings
            await loadReceivings(locationId: locationId)
            
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Failed to receive inventory"
            showError = true
            return false
        }
    }
    
    // MARK: - Create Adjustment
    func createAdjustment(
        type: AdjustmentType,
        productId: String,
        quantity: Int,
        locationId: String,
        reason: String?,
        notes: String?
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        
        // Check if this type has a quick endpoint
        let useQuickEndpoint: Bool
        let endpoint: APIEndpoint
        
        switch type {
        case .damage:
            endpoint = .adjustmentDamage
            useQuickEndpoint = true
        case .theft:
            endpoint = .adjustmentTheft
            useQuickEndpoint = true
        case .expired:
            endpoint = .adjustmentExpired
            useQuickEndpoint = true
        case .found:
            endpoint = .adjustmentFound
            useQuickEndpoint = true
        case .returnType:
            endpoint = .adjustmentReturn
            useQuickEndpoint = true
        case .countCorrection:
            endpoint = .adjustmentCountCorrection
            useQuickEndpoint = true
        case .writeOff:
            endpoint = .adjustmentWriteOff
            useQuickEndpoint = true
        default:
            endpoint = .createAdjustment
            useQuickEndpoint = false
        }
        
        // Use quick adjustment for specific types, full adjustment for generic
        if !useQuickEndpoint {
            let request = CreateAdjustmentRequest(
                locationId: locationId,
                productId: productId,
                type: type.rawValue,
                quantity: quantity,
                reason: reason,
                notes: notes,
                unitCost: nil,
                effectiveDate: nil,
                adjustedBy: nil,
                syncToSquare: true
            )
            
            do {
                let response: AdjustmentResponse = try await apiClient.request(
                    endpoint: endpoint,
                    body: request
                )
                successMessage = response.message
                showSuccess = true
                await loadAdjustments(locationId: locationId)
                return true
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
                showError = true
                return false
            } catch {
                errorMessage = "Failed to create adjustment"
                showError = true
                return false
            }
        } else {
            // Quick adjustment endpoints
            let request = QuickAdjustmentRequest(
                locationId: locationId,
                productId: productId,
                quantity: abs(quantity),
                reason: reason,
                notes: notes,
                syncToSquare: true
            )
            
            do {
                let response: AdjustmentResponse = try await apiClient.request(
                    endpoint: endpoint,
                    body: request
                )
                successMessage = response.message
                showSuccess = true
                await loadAdjustments(locationId: locationId)
                return true
            } catch let error as NetworkError {
                errorMessage = error.errorDescription
                showError = true
                return false
            } catch {
                errorMessage = "Failed to create adjustment"
                showError = true
                return false
            }
        }
    }
    
    // MARK: - Search Products
    func searchProducts(_ query: String) -> [Product] {
        guard !query.isEmpty else { return products }
        let lowercased = query.lowercased()
        return products.filter { product in
            product.displayName.lowercased().contains(lowercased) ||
            product.sku?.lowercased().contains(lowercased) == true ||
            product.name.lowercased().contains(lowercased)
        }
    }
}

// Note: ReceivingCreateResponse is defined in Inventory.swift

// MARK: - Receive Inventory View

struct ReceiveInventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showReceiveSheet = false
    
    var body: some View {
        VStack {
            // Quick action button
            VStack(spacing: 12) {
                Button {
                    showReceiveSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Receive New Inventory")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            
            Divider()
            
            // Recent receivings
            if viewModel.isLoadingReceivings {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.recentReceivings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No recent receivings")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Recent Receivings") {
                        ForEach(viewModel.recentReceivings.prefix(10)) { receiving in
                            ReceivingRow(receiving: receiving)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView(viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadProducts()
                await viewModel.loadSuppliers()
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadReceivings(locationId: locationId)
                }
            }
        }
        .refreshable {
            await viewModel.loadProducts()
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadReceivings(locationId: locationId)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage ?? "Operation completed")
        }
    }
}

// MARK: - Receiving Row

struct ReceivingRow: View {
    let receiving: InventoryReceiving
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(receiving.product?.displayName ?? "Unknown Product")
                    .font(.headline)
                Spacer()
                Text("+\(receiving.quantity)")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            HStack {
                if let invoiceNumber = receiving.invoiceNumber {
                    Text("Invoice: \(invoiceNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("$\(receiving.unitCost)/unit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(receiving.receivedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Total: $\(receiving.totalCost)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Receive Inventory Form View

struct ReceiveInventoryFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var selectedProduct: Product?
    @State private var showProductPicker = false
    @State private var quantity = ""
    @State private var unitCost = ""
    @State private var updateSellingPrice = false
    @State private var newSellingPrice = ""
    @State private var invoiceNumber = ""
    @State private var batchNumber = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year
    @State private var selectedSupplier: Supplier?
    @State private var showSupplierPicker = false
    @State private var notes = ""
    
    private var isValid: Bool {
        selectedProduct != nil &&
        !quantity.isEmpty &&
        Int(quantity) ?? 0 > 0 &&
        !unitCost.isEmpty &&
        Double(unitCost) ?? 0 >= 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Product Selection
                Section("Product") {
                    Button {
                        showProductPicker = true
                    } label: {
                        HStack {
                            if let product = selectedProduct {
                                VStack(alignment: .leading) {
                                    Text(product.displayName)
                                        .foregroundColor(.primary)
                                    if let sku = product.sku {
                                        Text("SKU: \(sku)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Select Product")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Quantity & Cost
                Section("Quantity & Cost") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Unit Cost")
                        Spacer()
                        Text("$")
                        TextField("0.00", text: $unitCost)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    if let qty = Int(quantity), qty > 0,
                       let cost = Double(unitCost), cost > 0 {
                        HStack {
                            Text("Total Cost")
                            Spacer()
                            Text("$\(String(format: "%.2f", Double(qty) * cost))")
                                .fontWeight(.semibold)
                        }
                    }
                }
                
                // Selling Price Update (Optional)
                Section {
                    Toggle("Update Selling Price", isOn: $updateSellingPrice)
                    
                    if updateSellingPrice {
                        HStack {
                            Text("New Price")
                            Spacer()
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $newSellingPrice)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("MXN")
                                .foregroundColor(.secondary)
                        }
                        
                        // Show current price if available
                        if let currentPrice = selectedProduct?.sellingPrice {
                            HStack {
                                Text("Current Price")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(String(format: "%.2f", currentPrice)) MXN")
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        
                        // Margin preview
                        if let cost = Double(unitCost), cost > 0,
                           let newPrice = Double(newSellingPrice), newPrice > 0 {
                            let margin = ((newPrice - cost) / newPrice) * 100
                            HStack {
                                Text("New Margin")
                                Spacer()
                                Text(String(format: "%.1f%%", margin))
                                    .foregroundColor(margin >= 20 ? .green : (margin >= 10 ? .orange : .red))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                } header: {
                    Text("Selling Price (Optional)")
                } footer: {
                    if updateSellingPrice {
                        Text("Price will be updated in Square POS.")
                    }
                }
                
                // Supplier
                Section("Supplier (Optional)") {
                    Button {
                        showSupplierPicker = true
                    } label: {
                        HStack {
                            if let supplier = selectedSupplier {
                                Text(supplier.name)
                                    .foregroundColor(.primary)
                            } else {
                                Text("Select Supplier")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedSupplier != nil {
                                Button {
                                    selectedSupplier = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Invoice & Batch
                Section("Reference Numbers (Optional)") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    TextField("Batch Number", text: $batchNumber)
                }
                
                // Expiry Date
                Section {
                    Toggle("Has Expiry Date", isOn: $hasExpiry)
                    
                    if hasExpiry {
                        DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                    }
                }
                
                // Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Receive Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveReceiving() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .sheet(isPresented: $showProductPicker) {
                ProductPickerView(
                    products: viewModel.products,
                    selectedProduct: $selectedProduct,
                    isLoading: viewModel.isLoadingProducts
                )
            }
            .sheet(isPresented: $showSupplierPicker) {
                SupplierPickerView(
                    suppliers: viewModel.suppliers,
                    selectedSupplier: $selectedSupplier
                )
            }
        }
    }
    
    private func saveReceiving() async {
        guard let product = selectedProduct,
              let qty = Int(quantity),
              let cost = Double(unitCost),
              let locationId = authManager.currentLocation?.id else { return }
        
        // Parse selling price if updating
        let priceToUpdate: Double? = updateSellingPrice ? Double(newSellingPrice.replacingOccurrences(of: ",", with: ".")) : nil
        
        let success = await viewModel.receiveInventory(
            productId: product.id,
            quantity: qty,
            unitCost: cost,
            locationId: locationId,
            supplierId: selectedSupplier?.id,
            invoiceNumber: invoiceNumber,
            batchNumber: batchNumber,
            expiryDate: hasExpiry ? expiryDate : nil,
            notes: notes,
            sellingPrice: priceToUpdate,
            syncPriceToSquare: true
        )
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Product Picker View

struct ProductPickerView: View {
    let products: [Product]
    @Binding var selectedProduct: Product?
    let isLoading: Bool
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        }
        let lowercased = searchText.lowercased()
        return products.filter { product in
            product.displayName.lowercased().contains(lowercased) ||
            product.sku?.lowercased().contains(lowercased) == true ||
            product.name.lowercased().contains(lowercased)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if products.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No products found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredProducts) { product in
                            Button {
                                selectedProduct = product
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 8) {
                                            if let sku = product.sku {
                                                Text("SKU: \(sku)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            if let category = product.category {
                                                Text(category.name)
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedProduct?.id == product.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search products")
                }
            }
            .navigationTitle("Select Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supplier Picker View

struct SupplierPickerView: View {
    let suppliers: [Supplier]
    @Binding var selectedSupplier: Supplier?
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private var filteredSuppliers: [Supplier] {
        if searchText.isEmpty {
            return suppliers
        }
        let lowercased = searchText.lowercased()
        return suppliers.filter { supplier in
            supplier.name.lowercased().contains(lowercased)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if suppliers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No suppliers found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSuppliers) { supplier in
                            Button {
                                selectedSupplier = supplier
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(supplier.name)
                                            .foregroundColor(.primary)
                                        
                                        if let contactInfo = supplier.contactInfo {
                                            Text(contactInfo)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedSupplier?.id == supplier.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search suppliers")
                }
            }
            .navigationTitle("Select Supplier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Adjustments List View

struct AdjustmentsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showAdjustmentSheet = false
    @State private var selectedAdjustmentType: AdjustmentType = .damage
    
    private let adjustmentTypes: [AdjustmentType] = [.damage, .theft, .expired, .found, .returnType, .countCorrection]
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick adjustment buttons - horizontal only, no pull to refresh
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(adjustmentTypes, id: \.self) { type in
                        Button {
                            selectedAdjustmentType = type
                            showAdjustmentSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 70)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 90)
            .padding(.vertical, 8)
            
            Divider()
            
            // Recent adjustments
            if viewModel.isLoadingAdjustments {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.recentAdjustments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No recent adjustments")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Recent Adjustments") {
                        ForEach(viewModel.recentAdjustments.prefix(10)) { adjustment in
                            AdjustmentRow(adjustment: adjustment)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadProducts()
                    if let locationId = authManager.currentLocation?.id {
                        await viewModel.loadAdjustments(locationId: locationId)
                    }
                }
            }
        }
        .sheet(isPresented: $showAdjustmentSheet) {
            AdjustmentFormView(adjustmentType: selectedAdjustmentType, viewModel: viewModel)
        }
        .onAppear {
            Task {
                await viewModel.loadProducts()
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadAdjustments(locationId: locationId)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage ?? "Operation completed")
        }
    }
}

// MARK: - Adjustment Row

struct AdjustmentRow: View {
    let adjustment: InventoryAdjustment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: adjustment.type.icon)
                    .foregroundColor(typeColor)
                
                Text(adjustment.product?.displayName ?? "Unknown Product")
                    .font(.headline)
                
                Spacer()
                
                Text(adjustment.quantityDisplay)
                    .font(.headline)
                    .foregroundColor(typeColor)
            }
            
            HStack {
                Text(adjustment.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundColor(typeColor)
                    .cornerRadius(4)
                
                if let reason = adjustment.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(adjustment.adjustedAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var typeColor: Color {
        if adjustment.type.isPositive {
            return .green
        } else if adjustment.type.isNegative {
            return .red
        }
        return .orange
    }
}

// MARK: - Adjustment Form View

struct AdjustmentFormView: View {
    let adjustmentType: AdjustmentType
    @ObservedObject var viewModel: InventoryViewModel
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedProduct: Product?
    @State private var showProductPicker = false
    @State private var quantity = ""
    @State private var reason = ""
    @State private var notes = ""
    
    private var isValid: Bool {
        selectedProduct != nil &&
        !quantity.isEmpty &&
        Int(quantity) ?? 0 != 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    Button {
                        showProductPicker = true
                    } label: {
                        HStack {
                            if let product = selectedProduct {
                                VStack(alignment: .leading) {
                                    Text(product.displayName)
                                        .foregroundColor(.primary)
                                    if let sku = product.sku {
                                        Text("SKU: \(sku)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } else {
                                Text("Select Product")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Quantity") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    if adjustmentType.isVariable {
                        Text("Enter positive to add, negative to remove")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if adjustmentType.isNegative {
                        Text("This will remove \(quantity.isEmpty ? "0" : quantity) units from inventory")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("This will add \(quantity.isEmpty ? "0" : quantity) units to inventory")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Section("Details") {
                    TextField("Reason", text: $reason)
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle(adjustmentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveAdjustment() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .sheet(isPresented: $showProductPicker) {
                ProductPickerView(
                    products: viewModel.products,
                    selectedProduct: $selectedProduct,
                    isLoading: viewModel.isLoadingProducts
                )
            }
        }
    }
    
    private func saveAdjustment() async {
        guard let product = selectedProduct,
              let qty = Int(quantity),
              let locationId = authManager.currentLocation?.id else { return }
        
        // For negative adjustment types, ensure quantity is positive (API handles sign)
        let adjustedQty = adjustmentType.isNegative ? abs(qty) : qty
        
        let success = await viewModel.createAdjustment(
            type: adjustmentType,
            productId: product.id,
            quantity: adjustedQty,
            locationId: locationId,
            reason: reason.isEmpty ? nil : reason,
            notes: notes.isEmpty ? nil : notes
        )
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Receiving History View

struct ReceivingHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InventoryViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoadingReceivings {
                ProgressView("Loading history...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.recentReceivings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No receiving history")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.recentReceivings) { receiving in
                        ReceivingRow(receiving: receiving)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            Task {
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadReceivings(locationId: locationId)
                }
            }
        }
        .refreshable {
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadReceivings(locationId: locationId)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

// MARK: - Preview

#Preview {
    InventoryView()
        .environmentObject(AuthManager.shared)
}
