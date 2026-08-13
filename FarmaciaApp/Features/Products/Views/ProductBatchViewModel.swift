import Foundation

// MARK: - Product Batch ViewModel (FIFO valuation + aging risk data)

@MainActor
class ProductBatchViewModel: ObservableObject {
    @Published var batches: [BatchValuation] = []
    @Published var productAging: ProductAgingAnalysis?
    @Published var isLoading = false
    
    struct AgingInfo {
        let fresh: Int   // < 30 days
        let moderate: Int // 30-90 days
        let old: Int     // > 90 days
    }
    
    var agingSummary: AgingInfo? {
        guard !batches.isEmpty else { return nil }
        let fresh = batches.filter { $0.age < 30 }.count
        let moderate = batches.filter { $0.age >= 30 && $0.age < 90 }.count
        let old = batches.filter { $0.age >= 90 }.count
        return AgingInfo(fresh: fresh, moderate: moderate, old: old)
    }
    
    /// Cash at risk: value of batches > 90 days old
    var cashAtRisk: Double {
        guard let aging = productAging else { return 0 }
        return aging.bucketDistribution
            .filter { ($0.bucket.min) >= 91 }
            .reduce(0) { $0 + $1.cashValue }
    }
    
    private let apiClient = APIClient.shared
    
    func loadBatches(productId: String, locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Guard against task cancellation to preserve existing data
        guard !Task.isCancelled else { return }
        
        // Load valuation and aging data in parallel
        async let valuationResult: () = loadValuation(productId: productId, locationId: locationId)
        async let agingResult: () = loadAgingAnalysis(productId: productId, locationId: locationId)
        _ = await (valuationResult, agingResult)
    }
    
    private func loadValuation(productId: String, locationId: String) async {
        do {
            let response: ValuationReportResponse = try await apiClient.request(
                endpoint: .valuationReport,
                queryParams: [
                    "locationId": locationId,
                    "productId": productId
                ]
            )
            // Extract batches from the product valuation
            if let productValuation = response.data.byProduct.first {
                batches = productValuation.batches ?? []
            } else {
                batches = []
            }
        } catch is CancellationError {
            // Request was cancelled (e.g. pull-to-refresh ended) — keep existing data
            return
        } catch {
            print("Failed to load batch valuation: \(error)")
            // Only clear if this is a fresh load (no existing data)
            // On refresh, keep stale data visible rather than showing empty state
        }
    }
    
    private func loadAgingAnalysis(productId: String, locationId: String) async {
        do {
            let response: ProductAgingResponse = try await apiClient.request(
                endpoint: .agingProducts,
                queryParams: [
                    "locationId": locationId,
                    "limit": "500"
                ]
            )
            // Find this product in the aging analysis
            productAging = response.products.first { $0.productId == productId }
        } catch is CancellationError {
            // Request was cancelled — keep existing data
            return
        } catch {
            // Silent fail — aging data is supplementary, keep existing data on refresh
            print("Failed to load aging analysis: \(error)")
        }
    }
}

