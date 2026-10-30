import Foundation
import FarmaciaKit

// MARK: - Products Aging ViewModel (loads at-risk product IDs from aging service)

@MainActor
class ProductsAgingViewModel: ObservableObject {
    /// HIGH or CRITICAL products; unavailable if the load failed.
    @Published var atRisk: RiskSet = .loading
    @Published var productRiskLevels: [String: InventoryRiskLevel] = [:]
    
    private let apiClient = APIClient.shared

    /// Back to loading, e.g. for another store.
    func reset() {
        atRisk = .loading
        productRiskLevels = [:]
    }
    
    /// Load products with HIGH or CRITICAL risk from the aging service
    func loadAtRiskProducts(locationId: String) async {
        do {
            let response: ProductAgingResponse = try await apiClient.request(
                endpoint: .agingProducts,
                queryParams: [
                    "locationId": locationId,
                    "limit": "500"
                ]
            )
            
            var riskIds = Set<String>()
            var riskMap: [String: InventoryRiskLevel] = [:]
            
            for product in response.products {
                riskMap[product.productId] = product.riskLevel
                if product.riskLevel == .high || product.riskLevel == .critical {
                    riskIds.insert(product.productId)
                }
            }
            
            atRisk = .loaded(riskIds)
            productRiskLevels = riskMap
        } catch {
            // Not "nothing at risk": the En Riesgo chip shows it couldn't load.
            atRisk = atRisk.after(failure: error)
            if atRisk == .unavailable { productRiskLevels = [:] }
        }
    }
}
