import Foundation
import FarmaciaKit

// MARK: - Stock Alert ViewModel

/// Alertas' stock counts, from GET /products/counts (the whole catalog at this store).
@MainActor
class StockAlertViewModel: ObservableObject {
    @Published var isLoading = false

    /// Nil until the counts request succeeds: no counts, no card (alerts are supplementary).
    @Published private(set) var serverCounts: ProductCountsResponse?

    func count(_ list: AlertList) -> Int {
        serverCounts.flatMap(list.count) ?? 0
    }

    var needsAttention: Bool {
        AlertList.allCases.contains { count($0) > 0 }
    }

    func loadCounts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        if let counts: ProductCountsResponse = try? await APIClient.shared.request(
            endpoint: .productCounts, queryParams: ["locationId": locationId]
        ) {
            serverCounts = counts
        }
    }
}

/// One Alertas list, paged from the server in its ranked order (O6). Paging and
/// dropping late pages is `ProductListLoad`, shared with Productos.
@MainActor
final class AlertListViewModel: ObservableObject {
    @Published private(set) var rows: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var load = ProductListLoad()
    private let pageSize = 50

    /// Starts `list` over; a list already shown is kept (coming back from a product), but
    /// one whose page 1 never landed (cancelled by leaving the tab) loads again.
    /// A refresh keeps its rows on screen until page 1 lands.
    func show(_ list: AlertList, locationId: String, force: Bool = false) async {
        let query = ProductListQuery(locationId: locationId, alert: list)
        guard load.needsFirstPage(query, force: force) else { return }
        if load.shownQuery != query {
            rows = []
            load.showRows(of: nil)
        }
        await run(load.beginFirstPage(query))
    }

    func loadMore(after product: Product) async {
        guard product.id == rows.last?.id, let ticket = load.beginNextPage() else { return }
        await run(ticket)
    }

    /// A row changed on the detail (paused, restocked): update it, or drop it if it left the list.
    func update(_ product: Product) {
        guard let list = load.query?.alert, let index = rows.firstIndex(where: { $0.id == product.id }) else { return }
        if list.keeps(product.stockAlert) {
            rows[index] = product
        } else {
            rows.remove(at: index)
        }
    }

    private func run(_ ticket: ProductListLoad.Ticket) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: ProductListResponse = try await APIClient.shared.request(
                endpoint: .listProducts, queryParams: ticket.query.params(page: ticket.page, limit: pageSize))
            // A newer pick or refresh owns the screen: this page is dropped.
            guard load.accept(ticket, hasMore: response.hasMore ?? false) else { return }
            rows = ticket.page == 1 ? response.data : rows + response.data
        } catch {
            guard load.fail(ticket) else { return }
            isLoading = false
            if case NetworkError.cancelled = error { return }
            errorMessage = (error as? NetworkError)?.errorDescription ?? "No se pudo cargar la lista."
            return
        }
        isLoading = false
    }
}
