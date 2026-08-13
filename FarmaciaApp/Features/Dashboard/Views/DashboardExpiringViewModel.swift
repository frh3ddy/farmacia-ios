import Foundation

// MARK: - Dashboard Expiring Products ViewModel

@MainActor
class DashboardExpiringViewModel: ObservableObject {
    @Published var products: [ExpiringProduct] = []
    @Published var summary: ExpiringProductsSummary?
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    var hasExpiringProducts: Bool {
        !products.isEmpty
    }
    
    func loadExpiring(locationId: String) async {
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
            products = response.products
            summary = response.summary
        } catch {
            // Silent fail — expiry alerts are supplementary
            print("Failed to load expiring products: \(error)")
            products = []
            summary = nil
        }
    }
}

