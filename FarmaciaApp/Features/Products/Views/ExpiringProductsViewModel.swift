import Foundation

// MARK: - Expiring Products ViewModel (loads expiring product IDs from aging service)

@MainActor
class ExpiringProductsViewModel: ObservableObject {
    @Published var expiringProductIds: Set<String> = []
    @Published var expiringProducts: [ExpiringProduct] = []
    @Published var summary: ExpiringProductsSummary?
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    /// Load products with batches expiring within 90 days (or already expired)
    func loadExpiringProducts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ExpiringProductsResponse = try await apiClient.request(
                endpoint: .agingExpiring,
                queryParams: [
                    "locationId": locationId,
                    "withinDays": "90",
                    "includeExpired": "true"
                ]
            )
            
            expiringProducts = response.products
            summary = response.summary
            expiringProductIds = Set(response.products.map { $0.productId })
        } catch {
            // Silent fail — expiry data is supplementary
            print("Failed to load expiring products: \(error)")
            expiringProducts = []
            summary = nil
            expiringProductIds = []
        }
    }
}
