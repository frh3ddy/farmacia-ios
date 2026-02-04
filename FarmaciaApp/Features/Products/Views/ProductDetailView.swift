import SwiftUI

// MARK: - Product Detail View

struct ProductDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    
    @State private var showEditPrice = false
    @State private var isRefreshing = false
    @State private var currentProduct: Product?
    
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
                
                // Inventory Card
                inventoryCard
                
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
        .refreshable {
            await refreshProduct()
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
    
    // MARK: - Inventory Card
    
    private var inventoryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.blue)
                Text("Inventory")
                    .font(.headline)
            }
            
            Divider()
            
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
                
                // Stock Status
                stockStatusBadge
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
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
                    } footer: {
                        if syncToSquare {
                            Text("Price will be updated in Square POS immediately.")
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
                syncToSquare: syncToSquare
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
