import SwiftUI

// MARK: - Inventory View

struct InventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InventoryViewModel()
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
        .onAppear {
            Task {
                // Load data when view appears
                await viewModel.loadProducts()
                await viewModel.loadSuppliers()
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadReceivings(locationId: locationId, limit: 20)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK") { viewModel.clearSuccess() }
        } message: {
            Text(viewModel.successMessage ?? "Operation completed")
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
    @ObservedObject var viewModel: InventoryViewModel
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
            
            // Recent receivings list
            if viewModel.isLoadingReceivings {
                Spacer()
                ProgressView("Loading receivings...")
                Spacer()
            } else if viewModel.receivings.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No recent receivings")
                        .foregroundColor(.secondary)
                    Text("Tap the button above to receive inventory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                Text("Recent Receivings")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                List(viewModel.receivings.prefix(5)) { receiving in
                    ReceivingRowView(receiving: receiving)
                }
                .listStyle(.plain)
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView(viewModel: viewModel)
        }
        .refreshable {
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadReceivings(locationId: locationId, limit: 20)
            }
        }
    }
}

// MARK: - Receiving Row View

struct ReceivingRowView: View {
    let receiving: InventoryReceiving
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(receiving.product?.displayName ?? "Unknown Product")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(receiving.formattedTotalCost)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Label("\(receiving.quantity) units", systemImage: "cube.box")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("@")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(receiving.formattedUnitCost)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let squareSynced = receiving.squareSynced {
                    Image(systemName: squareSynced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(squareSynced ? .green : .orange)
                }
            }
            
            HStack {
                if let supplier = receiving.supplier {
                    Text(supplier.name)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                if let invoiceNumber = receiving.invoiceNumber {
                    Text("Invoice: \(invoiceNumber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(receiving.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Receive Inventory Form View

struct ReceiveInventoryFormView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedProduct: Product?
    @State private var selectedSupplier: SupplierInfo?
    @State private var quantity = ""
    @State private var unitCost = ""
    @State private var invoiceNumber = ""
    @State private var batchNumber = ""
    @State private var notes = ""
    @State private var expiryDate: Date?
    @State private var showExpiryPicker = false
    @State private var syncToSquare = false
    
    @State private var showProductPicker = false
    @State private var showSupplierPicker = false
    
    private var isValid: Bool {
        selectedProduct != nil &&
        !quantity.isEmpty &&
        Int(quantity) ?? 0 > 0 &&
        !unitCost.isEmpty &&
        Double(unitCost) ?? 0 >= 0
    }
    
    private var totalCost: Double {
        let qty = Double(quantity) ?? 0
        let cost = Double(unitCost) ?? 0
        return qty * cost
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Product Section
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
                
                // Quantity & Cost Section
                Section("Quantity & Cost") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    HStack {
                        Text("$")
                        TextField("Unit Cost", text: $unitCost)
                            .keyboardType(.decimalPad)
                    }
                    
                    if totalCost > 0 {
                        HStack {
                            Text("Total Cost")
                            Spacer()
                            Text(String(format: "$%.2f", totalCost))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                // Supplier Section
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
                
                // Optional Details
                Section("Additional Details (Optional)") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    
                    TextField("Batch Number", text: $batchNumber)
                    
                    // Expiry Date
                    HStack {
                        Text("Expiry Date")
                        Spacer()
                        if let date = expiryDate {
                            Text(date, style: .date)
                                .foregroundColor(.primary)
                            Button {
                                expiryDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button("Set Date") {
                                showExpiryPicker = true
                            }
                        }
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                // Square Sync
                Section {
                    Toggle("Sync to Square", isOn: $syncToSquare)
                } footer: {
                    Text("Enable to sync this receiving to Square inventory")
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
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .sheet(isPresented: $showProductPicker) {
                ProductPickerView(
                    products: viewModel.products,
                    selectedProduct: $selectedProduct,
                    isLoading: viewModel.isLoadingProducts,
                    onRefresh: { await viewModel.loadProducts() }
                )
            }
            .sheet(isPresented: $showSupplierPicker) {
                SupplierPickerView(
                    suppliers: viewModel.suppliers,
                    selectedSupplier: $selectedSupplier,
                    isLoading: viewModel.isLoadingSuppliers,
                    onRefresh: { await viewModel.loadSuppliers() }
                )
            }
            .sheet(isPresented: $showExpiryPicker) {
                DatePickerSheet(selectedDate: $expiryDate, title: "Expiry Date")
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
        }
    }
    
    private func saveReceiving() async {
        guard let product = selectedProduct,
              let qty = Int(quantity),
              let cost = Double(unitCost),
              let locationId = authManager.currentLocation?.id
        else { return }
        
        let success = await viewModel.receiveInventory(
            productId: product.id,
            quantity: qty,
            unitCost: cost,
            locationId: locationId,
            supplierId: selectedSupplier?.id,
            invoiceNumber: invoiceNumber,
            batchNumber: batchNumber,
            expiryDate: expiryDate,
            notes: notes,
            syncToSquare: syncToSquare
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
    let onRefresh: () async -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        }
        let query = searchText.lowercased()
        return products.filter { product in
            product.displayName.lowercased().contains(query) ||
            (product.sku?.lowercased().contains(query) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading products...")
                } else if products.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No products found")
                            .foregroundColor(.secondary)
                        Button("Refresh") {
                            Task { await onRefresh() }
                        }
                    }
                } else {
                    List(filteredProducts) { product in
                        Button {
                            selectedProduct = product
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName)
                                        .foregroundColor(.primary)
                                    if let sku = product.sku {
                                        Text("SKU: \(sku)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let category = product.category {
                                        Text(category.name)
                                            .font(.caption2)
                                            .foregroundColor(.blue)
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
                    .searchable(text: $searchText, prompt: "Search products...")
                }
            }
            .navigationTitle("Select Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await onRefresh()
            }
        }
    }
}

// MARK: - Supplier Picker View

struct SupplierPickerView: View {
    let suppliers: [SupplierInfo]
    @Binding var selectedSupplier: SupplierInfo?
    let isLoading: Bool
    let onRefresh: () async -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    private var filteredSuppliers: [SupplierInfo] {
        if searchText.isEmpty {
            return suppliers
        }
        let query = searchText.lowercased()
        return suppliers.filter { supplier in
            supplier.name.lowercased().contains(query) ||
            (supplier.initials?.contains { $0.lowercased().contains(query) } ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading suppliers...")
                } else if suppliers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No suppliers found")
                            .foregroundColor(.secondary)
                        Button("Refresh") {
                            Task { await onRefresh() }
                        }
                    }
                } else {
                    List(filteredSuppliers) { supplier in
                        Button {
                            selectedSupplier = supplier
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplier.name)
                                        .foregroundColor(.primary)
                                    if let initials = supplier.initials, !initials.isEmpty {
                                        Text("Initials: \(initials.joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let contact = supplier.contactInfo {
                                        Text(contact)
                                            .font(.caption2)
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
                    .searchable(text: $searchText, prompt: "Search suppliers...")
                }
            }
            .navigationTitle("Select Supplier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await onRefresh()
            }
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date?
    let title: String
    @Environment(\.dismiss) var dismiss
    @State private var tempDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    title,
                    selection: $tempDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedDate = tempDate
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
    @ObservedObject var viewModel: InventoryViewModel
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if viewModel.isLoadingReceivings {
                ProgressView("Loading history...")
            } else if viewModel.receivings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No receiving history")
                        .foregroundColor(.secondary)
                }
            } else {
                List(viewModel.receivings) { receiving in
                    ReceivingRowView(receiving: receiving)
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadReceivings(locationId: locationId, limit: 100)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    InventoryView()
        .environmentObject(AuthManager.shared)
}
