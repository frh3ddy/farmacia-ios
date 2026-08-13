import Foundation

// MARK: - Cost & Supplier ViewModel

@MainActor
class CostSupplierViewModel: ObservableObject {
    @Published var suppliers: [ProductSupplier] = []
    @Published var costHistory: [SupplierCostHistoryGroup] = []
    // Starts true: ProductDetailView always calls loadData() unconditionally
    // on appear, so the very first render should already show the loading
    // skeleton rather than briefly flashing the "no data yet" empty state
    // before .task fires — that flash-then-flip was the reflow on navigate-in.
    @Published var isLoading = true
    
    private let apiClient = APIClient.shared
    
    func loadData(productId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Guard against task cancellation to preserve existing data
        guard !Task.isCancelled else { return }
        
        // Load both in parallel
        async let suppliersResult: () = loadSuppliers(productId: productId)
        async let costHistoryResult: () = loadCostHistory(productId: productId)
        _ = await (suppliersResult, costHistoryResult)
    }
    
    private func loadSuppliers(productId: String) async {
        do {
            let response: ProductSuppliersResponse = try await apiClient.request(
                endpoint: .productSuppliers(productId: productId)
            )
            suppliers = response.suppliers
        } catch is CancellationError {
            // Request was cancelled (e.g. pull-to-refresh ended) — keep existing data
            return
        } catch {
            print("Failed to load product suppliers: \(error)")
            // Keep existing data on refresh errors rather than clearing
        }
    }
    
    private func loadCostHistory(productId: String) async {
        do {
            let response: ProductCostHistoryResponse = try await apiClient.request(
                endpoint: .productCostHistory(productId: productId)
            )
            costHistory = response.suppliers
        } catch is CancellationError {
            // Request was cancelled — keep existing data
            return
        } catch {
            print("Failed to load product cost history: \(error)")
            // Keep existing data on refresh errors rather than clearing
        }
    }
}
