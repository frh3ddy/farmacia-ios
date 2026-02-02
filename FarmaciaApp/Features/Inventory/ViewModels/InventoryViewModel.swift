import Foundation

// MARK: - Inventory View Model

@MainActor
class InventoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Data
    @Published var products: [Product] = []
    @Published var suppliers: [SupplierInfo] = []
    @Published var receivings: [InventoryReceiving] = []
    @Published var receivingSummary: ReceivingSummary?
    
    // Loading States
    @Published var isLoadingProducts = false
    @Published var isLoadingSuppliers = false
    @Published var isLoadingReceivings = false
    @Published var isSubmitting = false
    
    // Error Handling
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Success Feedback
    @Published var successMessage: String?
    @Published var showSuccess = false
    
    // MARK: - Private Properties
    
    private let apiClient = APIClient.shared
    
    // MARK: - Product Methods
    
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        errorMessage = nil
        
        do {
            let response: ProductsResponse = try await apiClient.request(endpoint: .listProducts)
            products = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load products"
            showError = true
        }
        
        isLoadingProducts = false
    }
    
    func searchProducts(query: String) -> [Product] {
        guard !query.isEmpty else { return products }
        let lowercasedQuery = query.lowercased()
        return products.filter { product in
            product.displayName.lowercased().contains(lowercasedQuery) ||
            (product.sku?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    // MARK: - Supplier Methods
    
    func loadSuppliers() async {
        guard !isLoadingSuppliers else { return }
        isLoadingSuppliers = true
        errorMessage = nil
        
        do {
            let response: SuppliersResponse = try await apiClient.request(endpoint: .listSuppliers)
            suppliers = response.suppliers.filter { $0.isActive }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load suppliers"
            showError = true
        }
        
        isLoadingSuppliers = false
    }
    
    func searchSuppliers(query: String) -> [SupplierInfo] {
        guard !query.isEmpty else { return suppliers }
        let lowercasedQuery = query.lowercased()
        return suppliers.filter { supplier in
            supplier.name.lowercased().contains(lowercasedQuery) ||
            (supplier.initials?.contains { $0.lowercased().contains(lowercasedQuery) } ?? false)
        }
    }
    
    // MARK: - Receiving Methods
    
    func loadReceivings(locationId: String, limit: Int? = nil) async {
        guard !isLoadingReceivings else { return }
        isLoadingReceivings = true
        errorMessage = nil
        
        do {
            var queryParams: [String: String] = [:]
            if let limit = limit {
                queryParams["limit"] = String(limit)
            }
            
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByLocation(locationId: locationId),
                queryParams: queryParams.isEmpty ? nil : queryParams
            )
            receivings = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load receivings"
            showError = true
        }
        
        isLoadingReceivings = false
    }
    
    func loadReceivingSummary(locationId: String) async {
        do {
            let response: ReceivingSummaryResponse = try await apiClient.request(
                endpoint: .receivingSummary(locationId: locationId)
            )
            receivingSummary = response.data
        } catch {
            // Summary is optional, don't show error
        }
    }
    
    func receiveInventory(
        productId: String,
        quantity: Int,
        unitCost: Double,
        locationId: String,
        supplierId: String? = nil,
        invoiceNumber: String? = nil,
        batchNumber: String? = nil,
        expiryDate: Date? = nil,
        manufacturingDate: Date? = nil,
        notes: String? = nil,
        syncToSquare: Bool = false
    ) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil
        
        let request = ReceiveInventoryRequest(
            locationId: locationId,
            productId: productId,
            quantity: quantity,
            unitCost: unitCost,
            supplierId: supplierId,
            invoiceNumber: invoiceNumber?.isEmpty == true ? nil : invoiceNumber,
            purchaseOrderId: nil,
            batchNumber: batchNumber?.isEmpty == true ? nil : batchNumber,
            expiryDate: expiryDate,
            manufacturingDate: manufacturingDate,
            receivedBy: nil, // Backend gets this from session
            notes: notes?.isEmpty == true ? nil : notes,
            syncToSquare: syncToSquare
        )
        
        do {
            let response: ReceivingCreateResponse = try await apiClient.request(
                endpoint: .receiveInventory,
                body: request
            )
            
            successMessage = response.message
            showSuccess = true
            
            // Reload receivings
            await loadReceivings(locationId: locationId, limit: 20)
            
            isSubmitting = false
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            isSubmitting = false
            return false
        } catch {
            errorMessage = "Failed to receive inventory"
            showError = true
            isSubmitting = false
            return false
        }
    }
    
    func retrySquareSync(receivingId: String) async -> Bool {
        isSubmitting = true
        
        do {
            let _: EmployeeActionResponse = try await apiClient.request(
                endpoint: .retrySquareSync(receivingId: receivingId)
            )
            
            successMessage = "Square sync initiated"
            showSuccess = true
            isSubmitting = false
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            isSubmitting = false
            return false
        } catch {
            errorMessage = "Failed to sync to Square"
            showError = true
            isSubmitting = false
            return false
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    func clearSuccess() {
        successMessage = nil
        showSuccess = false
    }
}
