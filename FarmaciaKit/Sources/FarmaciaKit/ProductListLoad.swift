import Foundation

// MARK: - Product List Load
//
// Page 1 loads from search, pull-to-refresh, first appear and tab switch; page 2+
// from infinite scroll. Each load takes a ticket and only applies its result if the
// ticket is still current, so a slow page 2 of the full catalog can't land inside
// newer search results, and an older page 1 can't replace a newer one.

public struct ProductListQuery: Hashable, Sendable {
    public let locationId: String
    /// Trimmed; empty means no search (the full catalog).
    public let search: String?

    public init(locationId: String, search: String?) {
        self.locationId = locationId
        let trimmed = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.search = trimmed.isEmpty ? nil : trimmed
    }
}

public struct ProductListLoad: Sendable {
    public struct Ticket: Equatable, Sendable {
        fileprivate let generation: Int
        public let query: ProductListQuery
        public let page: Int
    }

    public private(set) var query: ProductListQuery?
    public private(set) var currentPage = 0
    public private(set) var hasMore = false
    private var generation = 0
    private var inFlight: Ticket?

    public init() {}

    /// Starts over for `query`; any load still in flight becomes stale.
    public mutating func beginFirstPage(_ query: ProductListQuery) -> Ticket {
        generation += 1
        self.query = query
        currentPage = 0
        hasMore = false
        let ticket = Ticket(generation: generation, query: query, page: 1)
        inFlight = ticket
        return ticket
    }

    /// The next page for the current query, or nil while another load is in flight
    /// or there are no more pages.
    public mutating func beginNextPage() -> Ticket? {
        guard let query, inFlight == nil, hasMore else { return nil }
        let ticket = Ticket(generation: generation, query: query, page: currentPage + 1)
        inFlight = ticket
        return ticket
    }

    /// True if the result for `ticket` should be applied; records the page as loaded.
    public mutating func accept(_ ticket: Ticket, hasMore: Bool) -> Bool {
        guard ticket == inFlight else { return false }
        inFlight = nil
        currentPage = ticket.page
        self.hasMore = hasMore
        return true
    }

    /// The load for `ticket` failed or was cancelled; the same page can be retried.
    /// Returns false for a stale ticket, whose failure the caller should ignore.
    @discardableResult
    public mutating func fail(_ ticket: Ticket) -> Bool {
        guard ticket == inFlight else { return false }
        inFlight = nil
        return true
    }
}
