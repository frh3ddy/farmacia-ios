import Foundation

// MARK: - Products Aging ViewModel (loads at-risk product IDs from aging service)

@MainActor
class ProductsAgingViewModel: ObservableObject {
    @Published var atRiskProductIds: Set<String> = []
    @Published var productRiskLevels: [String: InventoryRiskLevel] = [:]
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    /// Load products with HIGH or CRITICAL risk from the aging service
    func loadAtRiskProducts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
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
            
            atRiskProductIds = riskIds
            productRiskLevels = riskMap
        } catch {
            // Silent fail — aging data is supplementary
            print("Failed to load aging data for products: \(error)")
            atRiskProductIds = []
            productRiskLevels = [:]
        }
    }
}
