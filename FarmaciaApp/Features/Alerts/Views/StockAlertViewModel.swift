import Foundation
import FarmaciaKit

// MARK: - Stock Alert ViewModel

/// Pre-computed fallback counts (avoids re-filtering `products` on every
/// access — see `StockAlertViewModel`).
private struct StockAlertCounts {
    var outOfStock = 0
    var lowStock = 0
    var lowMargin = 0
}

@MainActor
class StockAlertViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false

    /// Server-side counts; nil until the counts request succeeds.
    @Published private(set) var serverCounts: ProductCountsResponse?

    private let apiClient = APIClient.shared

    // Computed once when `products` changes, NOT on every SwiftUI render.
    // Only used as a fallback when serverCounts hasn't arrived yet — the
    // count properties below are each read several times per render pass
    // (needsAttention, the alert card, the restock action).
    private var fallbackCounts = StockAlertCounts()

    var outOfStockCount: Int {
        serverCounts?.outOfStock ?? fallbackCounts.outOfStock
    }

    var lowStockCount: Int {
        serverCounts?.lowStock ?? fallbackCounts.lowStock
    }

    var lowMarginCount: Int {
        serverCounts?.lowMargin ?? fallbackCounts.lowMargin
    }

    var needsAttention: Bool {
        outOfStockCount > 0 || lowStockCount > 0 || lowMarginCount > 0
    }

    func loadProducts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }

        // Counts come from the server aggregate (correct for the whole catalog).
        // The product list is bounded to 200 — only used by the alert list view
        // and the restock shopping list, which need concrete Product rows.
        async let countsFetch: ProductCountsResponse? = try? apiClient.request(
            endpoint: .productCounts,
            queryParams: ["locationId": locationId]
        )
        async let listFetch: ProductListResponse? = try? apiClient.request(
            endpoint: .listProducts,
            queryParams: ["locationId": locationId, "limit": "200"]
        )

        let (counts, list) = await (countsFetch, listFetch)

        if let counts {
            serverCounts = counts
        }
        if let list {
            products = list.data
            recalculateFallbackCounts()
        } else {
            // Silent fail — alerts are supplementary
            print("Failed to load products for stock alerts")
        }
    }

    /// Fallback counts (server counts failed) — recalculated when products change.
    private func recalculateFallbackCounts() {
        var c = StockAlertCounts()
        let tally = StockTally(products.map { ($0.totalInventory ?? 0, $0.stockAlert) })
        c.outOfStock = tally.outOfStock
        c.lowStock = tally.lowStock
        c.lowMargin = products.count { ($0.profitMargin ?? 100) < 10 }
        fallbackCounts = c
    }
}

