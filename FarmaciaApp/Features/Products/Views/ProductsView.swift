import SwiftUI

// MARK: - Products View

struct ProductsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ProductsViewModel()
    @State private var showCreateProduct = false
    @State private var searchText = ""
    
    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return viewModel.products
        }
        return viewModel.products.filter { product in
            product.displayName.localizedCaseInsensitiveContains(searchText) ||
            (product.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.products.isEmpty {
                    loadingView
                } else if viewModel.products.isEmpty {
                    emptyStateView
                } else {
                    productsList
                }
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if authManager.isOwner || authManager.isManager {
                        Button {
                            showCreateProduct = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search products...")
            .refreshable {
                await loadProducts()
            }
            .sheet(isPresented: $showCreateProduct) {
                CreateProductView()
                    .onDisappear {
                        Task {
                            await loadProducts()
                        }
                    }
            }
            .task {
                await loadProducts()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
                Button("Retry") {
                    Task {
                        await loadProducts()
                    }
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading products...")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Products")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Products synced from Square will appear here.\nYou can also create products manually.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if authManager.isOwner || authManager.isManager {
                Button {
                    showCreateProduct = true
                } label: {
                    Label("Create Product", systemImage: "plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Products List
    
    private var productsList: some View {
        List {
            // Summary Section
            Section {
                HStack {
                    summaryItem(
                        title: "Total",
                        value: "\(viewModel.products.count)",
                        icon: "shippingbox.fill",
                        color: .blue
                    )
                    
                    Divider()
                    
                    summaryItem(
                        title: "Synced",
                        value: "\(viewModel.products.filter { $0.hasSquareSync == true }.count)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    Divider()
                    
                    summaryItem(
                        title: "Local",
                        value: "\(viewModel.products.filter { $0.hasSquareSync != true }.count)",
                        icon: "iphone",
                        color: .orange
                    )
                }
                .padding(.vertical, 8)
            }
            
            // Products Section
            Section {
                ForEach(filteredProducts) { product in
                    NavigationLink {
                        ProductDetailView(product: product)
                    } label: {
                        ProductRow(product: product)
                    }
                }
            } header: {
                if !searchText.isEmpty {
                    Text("\(filteredProducts.count) results")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Summary Item
    
    private func summaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadProducts() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await viewModel.loadProducts(locationId: locationId)
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image or Placeholder
            if let imageUrl = product.squareImageUrl, let url = URL(string: imageUrl) {
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
                .frame(width: 50, height: 50)
                .cornerRadius(8)
            } else {
                productPlaceholder
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let sku = product.sku {
                        Text(sku)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if product.hasSquareSync == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Price and Stock
            VStack(alignment: .trailing, spacing: 4) {
                if let price = product.formattedPrice {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                if let stock = product.totalInventory {
                    Text("\(stock) units")
                        .font(.caption)
                        .foregroundColor(stock > 0 ? .secondary : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
            
            Image(systemName: "shippingbox")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Products View Model

@MainActor
class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let apiClient = APIClient.shared
    
    func loadProducts(locationId: String) async {
        isLoading = true
        
        do {
            let response: ProductListResponse = try await apiClient.request(
                endpoint: .listProducts,
                queryParams: ["locationId": locationId]
            )
            products = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Failed to load products"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ProductsView()
        .environmentObject(AuthManager.shared)
}
