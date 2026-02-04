import SwiftUI

// MARK: - Create Product View

struct CreateProductView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = CreateProductViewModel()
    
    var body: some View {
        NavigationStack {
            Form {
                // Product Info Section
                Section {
                    TextField("Product Name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("SKU (Optional)", text: $viewModel.sku)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    TextField("Description (Optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Product Information")
                } footer: {
                    Text("SKU helps identify products quickly. Leave empty to auto-generate.")
                }
                
                // Pricing Section
                Section {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $viewModel.sellingPriceText)
                            .keyboardType(.decimalPad)
                        Text("MXN")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Selling Price")
                } footer: {
                    Text("The price customers will pay at the register.")
                }
                
                // Initial Inventory Section (Optional)
                Section {
                    Toggle("Add Initial Stock", isOn: $viewModel.hasInitialStock)
                    
                    if viewModel.hasInitialStock {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            TextField("0", text: $viewModel.initialStockText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("units")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Cost per Unit")
                            Spacer()
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $viewModel.costPriceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("MXN")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Initial Inventory (Optional)")
                } footer: {
                    if viewModel.hasInitialStock {
                        Text("This will create opening balance inventory at the current location.")
                    } else {
                        Text("You can receive inventory later from the Inventory tab.")
                    }
                }
                
                // Margin Preview
                if viewModel.showMarginPreview {
                    Section {
                        marginPreviewRow
                    } header: {
                        Text("Margin Preview")
                    }
                }
                
                // Square Sync Section
                Section {
                    Toggle("Sync to Square POS", isOn: $viewModel.syncToSquare)
                } header: {
                    Text("Square Integration")
                } footer: {
                    if viewModel.syncToSquare {
                        Text("Product will appear in Square POS for sales.")
                    } else {
                        Text("Product will be tracked locally only. Not visible in Square POS.")
                    }
                }
            }
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createProduct()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    loadingOverlay
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Product Created", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }
    
    // MARK: - Margin Preview
    
    private var marginPreviewRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profit per Unit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let profit = viewModel.profitPerUnit {
                    Text(formatCurrency(profit))
                        .font(.headline)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Margin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let margin = viewModel.marginPercent {
                    Text(String(format: "%.1f%%", margin))
                        .font(.headline)
                        .foregroundColor(margin >= 20 ? .green : (margin >= 10 ? .orange : .red))
                }
            }
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Creating product...")
                    .font(.headline)
                
                if viewModel.syncToSquare {
                    Text("Syncing to Square...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Actions
    
    private func createProduct() async {
        guard let locationId = authManager.currentLocation?.id else {
            viewModel.errorMessage = "No location selected"
            viewModel.showError = true
            return
        }
        
        await viewModel.createProduct(locationId: locationId)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Create Product View Model

@MainActor
class CreateProductViewModel: ObservableObject {
    // Form fields
    @Published var name = ""
    @Published var sku = ""
    @Published var description = ""
    @Published var sellingPriceText = ""
    @Published var costPriceText = ""
    @Published var initialStockText = ""
    @Published var hasInitialStock = false
    @Published var syncToSquare = true
    
    // State
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    private let apiClient = APIClient.shared
    
    // MARK: - Computed Properties
    
    var sellingPrice: Double? {
        Double(sellingPriceText.replacingOccurrences(of: ",", with: "."))
    }
    
    var costPrice: Double? {
        Double(costPriceText.replacingOccurrences(of: ",", with: "."))
    }
    
    var initialStock: Int? {
        Int(initialStockText)
    }
    
    var isValid: Bool {
        // Name is required
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        
        // Selling price is required and must be positive
        guard let price = sellingPrice, price > 0 else { return false }
        
        // If initial stock is enabled, validate stock and cost
        if hasInitialStock {
            guard let stock = initialStock, stock > 0 else { return false }
            guard let cost = costPrice, cost >= 0 else { return false }
        }
        
        return true
    }
    
    var showMarginPreview: Bool {
        hasInitialStock && sellingPrice != nil && costPrice != nil
    }
    
    var profitPerUnit: Double? {
        guard let price = sellingPrice, let cost = costPrice else { return nil }
        return price - cost
    }
    
    var marginPercent: Double? {
        guard let price = sellingPrice, let cost = costPrice, price > 0 else { return nil }
        return ((price - cost) / price) * 100
    }
    
    // MARK: - Actions
    
    func createProduct(locationId: String) async {
        isSubmitting = true
        
        do {
            let request = CreateProductRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                sku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                sellingPrice: sellingPrice ?? 0,
                costPrice: hasInitialStock ? costPrice : nil,
                initialStock: hasInitialStock ? initialStock : nil,
                locationId: locationId,
                syncToSquare: syncToSquare
            )
            
            let response: APIResponse<CreateProductResponse> = try await apiClient.request(
                endpoint: .createProduct,
                body: request
            )
            
            if let data = response.data {
                var message = "Product \"\(name)\" created successfully!"
                if data.squareSynced {
                    message += "\n✓ Synced to Square POS"
                }
                if data.inventoryCreated {
                    message += "\n✓ Initial inventory added"
                }
                successMessage = message
                showSuccess = true
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Failed to create product"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
    }
}

// MARK: - API Response wrapper (if not already defined)

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
}

// MARK: - Preview

#Preview {
    CreateProductView()
        .environmentObject(AuthManager.shared)
}
