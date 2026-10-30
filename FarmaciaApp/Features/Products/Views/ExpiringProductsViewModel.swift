import Foundation
import FarmaciaKit

// MARK: - Expiring Products ViewModel (loads expiring product IDs from aging service)

@MainActor
class ExpiringProductsViewModel: ObservableObject {
    /// Products with a lot expiring within 90 days (or already expired); unavailable if the load failed.
    @Published var expiring: RiskSet = .loading
    
    private let apiClient = APIClient.shared
    
    /// Load products with batches expiring within 90 days (or already expired)
    func loadExpiringProducts(locationId: String) async {
        do {
            let response: ExpiringProductsResponse = try await apiClient.request(
                endpoint: .agingExpiring,
                queryParams: [
                    "locationId": locationId,
                    "withinDays": "90",
                    "includeExpired": "true"
                ]
            )
            
            expiring = .loaded(Set(response.products.map { $0.productId }))
        } catch {
            // Not "nothing expiring": the Por Vencer chip shows it couldn't load.
            expiring = expiring.after(failure: error)
        }
    }
}
