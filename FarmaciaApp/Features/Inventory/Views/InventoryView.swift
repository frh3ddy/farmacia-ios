import SwiftUI

// MARK: - Inventory View Model

@MainActor
class InventoryReceivingViewModel: ObservableObject {
    @Published var receivings: [InventoryReceiving] = []
    @Published var products: [Product] = []
    @Published var suppliers: [SupplierInfo] = []
    @Published var isLoading = false
    @Published var isLoadingProducts = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var successMessage: String?
    @Published var showSuccess = false
    
    private let apiClient = APIClient.shared
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoadingProducts = true
        
        do {
            let response: ProductsResponse = try await apiClient.request(endpoint: .listProducts)
            products = response.data.filter { $0.isActive }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoadingProducts = false
    }
    
    // MARK: - Load Suppliers
    
    func loadSuppliers() async {
        do {
            let response: SuppliersResponse = try await apiClient.request(endpoint: .listSuppliers)
            suppliers = response.suppliers.filter { $0.isActive }
        } catch let error as NetworkError {
            // Non-critical, just log
            print("Failed to load suppliers: \(error.errorDescription ?? "")")
        } catch {
            print("Failed to load suppliers: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Receivings
    
    func loadReceivings(locationId: String) async {
        isLoading = true
        
        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByLocation(locationId: locationId),
                queryParams: ["limit": "50"]
            )
            receivings = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    // MARK: - Receive Inventory
    
    func receiveInventory(
        productId: String,
        quantity: Int,
        unitCost: Double,
        locationId: String,
        supplierId: String?,
        invoiceNumber: String?,
        notes: String?,
        expiryDate: Date?,
        batchNumber: String?
    ) async -> Bool {
        isSubmitting = true
        
        do {
            let request = ReceiveInventoryRequest(
                locationId: locationId,
                productId: productId,
                quantity: quantity,
                unitCost: unitCost,
                supplierId: supplierId?.isEmpty == true ? nil : supplierId,
                invoiceNumber: invoiceNumber?.isEmpty == true ? nil : invoiceNumber,
                purchaseOrderId: nil,
                batchNumber: batchNumber?.isEmpty == true ? nil : batchNumber,
                expiryDate: expiryDate,
                manufacturingDate: nil,
                receivedBy: nil, // Will be set by backend from session
                notes: notes?.isEmpty == true ? nil : notes,
                syncToSquare: true
            )
            
            let response: ReceivingCreateResponse = try await apiClient.request(
                endpoint: .receiveInventory,
                body: request
            )
            
            successMessage = response.message
            showSuccess = true
            
            // Reload receivings
            await loadReceivings(locationId: locationId)
            
            isSubmitting = false
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
        return false
    }
    
    // MARK: - Get Receiving Detail
    
    func getReceiving(id: String) async -> InventoryReceiving? {
        do {
            let response: ReceivingGetResponse = try await apiClient.request(
                endpoint: .getReceiving(id: id)
            )
            return response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        return nil
    }
}

// MARK: - Inventory View

struct InventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InventoryReceivingViewModel()
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
                        ReceiveInventoryView(viewModel: viewModel)
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
                    ReceivingHistoryView(viewModel: viewModel)
                }
            }
            .navigationTitle("Inventory")
        }
        .task {
            // Load products and suppliers when view appears
            await viewModel.loadProducts()
            await viewModel.loadSuppliers()
            
            // Load receivings for current location
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadReceivings(locationId: locationId)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "Operation completed successfully")
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

// MARK: - Receive Inventory View

struct ReceiveInventoryView: View {
    @ObservedObject var viewModel: InventoryReceivingViewModel
    @EnvironmentObject var authManager: AuthManager
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
            
            // Recent Receivings
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.receivings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recent receivings")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(viewModel.receivings.prefix(10)) { receiving in
                            ReceivingRowView(receiving: receiving)
                        }
                    } header: {
                        Text("Recent Receivings")
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView(
                viewModel: viewModel,
                locationId: authManager.currentLocation?.id ?? ""
            )
        }
    }
}

// MARK: - Receiving Row View

struct ReceivingRowView: View {
    let receiving: InventoryReceiving
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(receiving.product?.displayName ?? "Unknown Product")
                    .font(.headline)
                
                HStack {
                    Text("\(receiving.quantity) units")
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(receiving.formattedUnitCost)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                Text(receiving.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(receiving.formattedTotalCost)
                    .font(.headline)
                    .foregroundColor(.green)
                
                if let synced = receiving.squareSynced, synced {
                    Label("Synced", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Receive Inventory Form View

struct ReceiveInventoryFormView: View {
    @ObservedObject var viewModel: InventoryReceivingViewModel
    let locationId: String
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProduct: Product?
    @State private var selectedSupplier: SupplierInfo?
    @State private var productSearchText = ""
    @State private var quantity = ""
    @State private var unitCost = ""
    @State private var invoiceNumber = ""
    @State private var batchNumber = ""
    @State private var notes = ""
    @State private var expiryDate: Date?
    @State private var hasExpiryDate = false
    
    @State private var showProductPicker = false
    @State private var showSupplierPicker = false
    
    var filteredProducts: [Product] {
        if productSearchText.isEmpty {
            return viewModel.products
        }
        return viewModel.products.filter {
            $0.displayName.localizedCaseInsensitiveContains(productSearchText) ||
            ($0.sku?.localizedCaseInsensitiveContains(productSearchText) ?? false) ||
            ($0.barcode?.localizedCaseInsensitiveContains(productSearchText) ?? false)
        }
    }
    
    var isFormValid: Bool {
        guard let _ = selectedProduct,
              let qty = Int(quantity), qty > 0,
              let cost = Double(unitCost), cost >= 0 else {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Product Section
                Section("Product") {
                    if let product = selectedProduct {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(product.displayName)
                                    .font(.headline)
                                if let sku = product.sku {
                                    Text("SKU: \(sku)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Change") {
                                showProductPicker = true
                            }
                        }
                    } else {
                        Button {
                            showProductPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Select Product")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Quantity & Cost Section
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
                       let cost = Double(unitCost), cost >= 0 {
                        HStack {
                            Text("Total Cost")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "$%.2f", Double(qty) * cost))
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Supplier Section
                Section("Supplier (Optional)") {
                    if let supplier = selectedSupplier {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(supplier.name)
                                    .font(.headline)
                                if let contact = supplier.contactInfo, !contact.isEmpty {
                                    Text(contact)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Clear") {
                                selectedSupplier = nil
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button {
                            showSupplierPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "person.2")
                                Text("Select Supplier")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Optional Details Section
                Section("Optional Details") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    TextField("Batch Number", text: $batchNumber)
                    
                    Toggle("Has Expiry Date", isOn: $hasExpiryDate)
                    
                    if hasExpiryDate {
                        DatePicker(
                            "Expiry Date",
                            selection: Binding(
                                get: { expiryDate ?? Date() },
                                set: { expiryDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
                
                // Notes Section
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
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
                        Task {
                            await saveReceiving()
                        }
                    }
                    .disabled(!isFormValid || viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
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
              let qty = Int(quantity), qty > 0,
              let cost = Double(unitCost), cost >= 0 else {
            return
        }
        
        let success = await viewModel.receiveInventory(
            productId: product.id,
            quantity: qty,
            unitCost: cost,
            locationId: locationId,
            supplierId: selectedSupplier?.id,
            invoiceNumber: invoiceNumber.isEmpty ? nil : invoiceNumber,
            notes: notes.isEmpty ? nil : notes,
            expiryDate: hasExpiryDate ? expiryDate : nil,
            batchNumber: batchNumber.isEmpty ? nil : batchNumber
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
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        }
        return products.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.sku?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.barcode?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading products...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredProducts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No products available" : "No products found")
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
                                        
                                        HStack {
                                            if let sku = product.sku {
                                                Text("SKU: \(sku)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            if let barcode = product.barcode {
                                                Text("BC: \(barcode)")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
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
                }
            }
            .navigationTitle("Select Product")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name, SKU, or barcode")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
    let suppliers: [SupplierInfo]
    @Binding var selectedSupplier: SupplierInfo?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredSuppliers: [SupplierInfo] {
        if searchText.isEmpty {
            return suppliers
        }
        return suppliers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.initials?.joined().localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredSuppliers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No suppliers available" : "No suppliers found")
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
                                        
                                        if let contact = supplier.contactInfo, !contact.isEmpty {
                                            Text(contact)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let initials = supplier.initials, !initials.isEmpty {
                                            Text("Initials: \(initials.joined(separator: ", "))")
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
                }
            }
            .navigationTitle("Select Supplier")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search suppliers")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
    @State private var showAdjustmentSheet = false
    @State private var selectedAdjustmentType: AdjustmentType?
    
    var body: some View {
        VStack {
            // Quick adjustment buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([AdjustmentType.damage, .theft, .expired, .found, .returnType, .countCorrection], id: \.self) { type in
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
            .padding(.vertical)
            
            Divider()
            
            // Placeholder for recent adjustments
            Text("Recent adjustments will appear here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAdjustmentSheet) {
            if let type = selectedAdjustmentType {
                AdjustmentFormView(adjustmentType: type)
            }
        }
    }
}

// MARK: - Adjustment Form View

struct AdjustmentFormView: View {
    let adjustmentType: AdjustmentType
    @Environment(\.dismiss) var dismiss
    @State private var productSearch = ""
    @State private var quantity = ""
    @State private var reason = ""
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Search product...", text: $productSearch)
                }
                
                Section("Quantity") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    if adjustmentType.isVariable {
                        Text("Enter positive to add, negative to remove")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        // TODO: Save adjustment
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

// MARK: - Receiving History View

struct ReceivingHistoryView: View {
    @ObservedObject var viewModel: InventoryReceivingViewModel
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.receivings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No receiving history")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.receivings) { receiving in
                        NavigationLink {
                            ReceivingDetailView(receiving: receiving)
                        } label: {
                            ReceivingRowView(receiving: receiving)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    if let locationId = authManager.currentLocation?.id {
                        await viewModel.loadReceivings(locationId: locationId)
                    }
                }
            }
        }
    }
}

// MARK: - Receiving Detail View

struct ReceivingDetailView: View {
    let receiving: InventoryReceiving
    
    var body: some View {
        List {
            Section("Product") {
                LabeledContent("Name", value: receiving.product?.displayName ?? "Unknown")
                if let sku = receiving.product?.sku {
                    LabeledContent("SKU", value: sku)
                }
            }
            
            Section("Quantity & Cost") {
                LabeledContent("Quantity", value: "\(receiving.quantity)")
                LabeledContent("Unit Cost", value: receiving.formattedUnitCost)
                LabeledContent("Total Cost", value: receiving.formattedTotalCost)
            }
            
            Section("Details") {
                LabeledContent("Received", value: receiving.formattedDate)
                
                if let supplier = receiving.supplier {
                    LabeledContent("Supplier", value: supplier.name)
                }
                
                if let invoice = receiving.invoiceNumber {
                    LabeledContent("Invoice #", value: invoice)
                }
                
                if let batch = receiving.batchNumber {
                    LabeledContent("Batch #", value: batch)
                }
                
                if let expiry = receiving.expiryDate {
                    LabeledContent("Expiry Date") {
                        Text(expiry, style: .date)
                    }
                }
            }
            
            if let notes = receiving.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
            
            Section("Sync Status") {
                HStack {
                    Text("Square Synced")
                    Spacer()
                    if receiving.squareSynced == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                
                if let error = receiving.squareSyncError {
                    LabeledContent("Error", value: error)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Receiving Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    InventoryView()
        .environmentObject(AuthManager.shared)
}
