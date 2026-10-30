import Testing
@testable import FarmaciaKit

/// The product list loads page 1 from several triggers (search, refresh, tab switch)
/// and page 2+ from infinite scroll. Only results for the current query and page may land.
/// (Mutating calls sit outside `#expect`, which can't take them.)
struct ProductListLoadTests {
    let catalog = ProductListQuery(locationId: "centro", search: nil)
    let ibup = ProductListQuery(locationId: "centro", search: "ibup")

    /// A state with page 1 of `query` loaded and more pages available.
    func loaded(_ query: ProductListQuery) -> ProductListLoad {
        var state = ProductListLoad()
        _ = state.accept(state.beginFirstPage(query), hasMore: true)
        return state
    }

    @Test("given searches \"  ibup \" and \"ibup\" at the same location, should be the same query")
    func normalizesSearch() {
        #expect(ProductListQuery(locationId: "centro", search: "  ibup ") == ibup)
        #expect(ProductListQuery(locationId: "centro", search: "   ") == catalog)
        #expect(ProductListQuery(locationId: "norte", search: "ibup") != ibup)
    }

    @Test("given the same search with a different filter, should be a different query; given Todos, the same as no filter")
    func filterIsPartOfTheQuery() {
        let expiring = ProductListQuery(locationId: "centro", search: "ibup", filter: .expiringSoon)
        #expect(expiring != ibup)
        #expect(expiring.filter == .expiringSoon)
        #expect(ProductListQuery(locationId: "centro", search: "ibup", filter: .all) == ibup)
    }

    @Test("given each filter, should send its API value; given Todos, none",
          arguments: [(ProductFilter.all, nil), (.lowStock, "lowStock"), (.outOfStock, "outOfStock"), (.inStock, "inStock"),
                      (.atRisk, "atRisk"), (.expiringSoon, "expiring"), (.lowMargin, "lowMargin")] as [(ProductFilter, String?)])
    func apiValue(filter: ProductFilter, expected: String?) {
        #expect(filter.apiValue == expected)
    }

    @Test("given a search or a filter, isCatalog should be false; given neither, true")
    func isCatalog() {
        #expect(catalog.isCatalog)
        #expect(!ibup.isCatalog)
        #expect(!ProductListQuery(locationId: "centro", search: nil, filter: .lowStock).isCatalog)
    }

    @Test("given a page-2 load started for the full catalog, when a search begins before it returns, should reject the page-2 result")
    func stalePageTwo() throws {
        var state = loaded(catalog)
        let pageTwo = try #require(state.beginNextPage() as ProductListLoad.Ticket?)
        let search = state.beginFirstPage(ibup)
        let searchAccepted = state.accept(search, hasMore: false)
        let pageTwoAccepted = state.accept(pageTwo, hasMore: true)

        #expect(searchAccepted)
        #expect(!pageTwoAccepted)
        #expect(state.currentPage == 1)
        #expect(!state.hasMore)
    }

    @Test("given a refresh of the same catalog while its page 2 is in flight, should reject the old page 2")
    func refreshDuringPageTwo() throws {
        var state = loaded(catalog)
        let oldPageTwo = try #require(state.beginNextPage() as ProductListLoad.Ticket?)
        let refresh = state.beginFirstPage(catalog)
        let oldPageTwoAccepted = state.accept(oldPageTwo, hasMore: true)
        let refreshAccepted = state.accept(refresh, hasMore: true)

        #expect(!oldPageTwoAccepted)
        #expect(refreshAccepted)
        #expect(state.currentPage == 1)
    }

    @Test("given two first-page loads, should accept only the latest")
    func latestFirstPageWins() {
        var state = ProductListLoad()
        let older = state.beginFirstPage(catalog)
        let newer = state.beginFirstPage(ibup)
        let olderAccepted = state.accept(older, hasMore: true)
        let newerAccepted = state.accept(newer, hasMore: true)

        #expect(!olderAccepted)
        #expect(newerAccepted)
        #expect(state.query == ibup)
    }

    @Test("given page 2 for the current query, should accept it and move to the next page")
    func pageTwoAdvances() throws {
        var state = loaded(catalog)
        let pageTwo = try #require(state.beginNextPage() as ProductListLoad.Ticket?)
        let accepted = state.accept(pageTwo, hasMore: true)
        let pageThree = state.beginNextPage()

        #expect(pageTwo.page == 2)
        #expect(pageTwo.query == catalog)
        #expect(accepted)
        #expect(state.currentPage == 2)
        #expect(pageThree?.page == 3)
    }

    @Test("given a load-more before anything loaded, during page 1, during another load-more, or after the last page, should not start one")
    func noLoadMore() throws {
        var state = ProductListLoad()
        let beforeLoad = state.beginNextPage()
        let first = state.beginFirstPage(catalog)
        let duringFirst = state.beginNextPage()
        _ = state.accept(first, hasMore: true)
        let pageTwo = try #require(state.beginNextPage() as ProductListLoad.Ticket?)
        let duringPageTwo = state.beginNextPage()
        _ = state.accept(pageTwo, hasMore: false)
        let afterLast = state.beginNextPage()

        #expect(beforeLoad == nil)
        #expect(duringFirst == nil)
        #expect(duringPageTwo == nil)
        #expect(afterLast == nil)
    }

    @Test("given a failed load-more, should allow retrying the same page")
    func retryAfterFailure() throws {
        var state = loaded(catalog)
        let wasCurrent = state.fail(try #require(state.beginNextPage() as ProductListLoad.Ticket?))
        let retry = state.beginNextPage()
        #expect(wasCurrent)
        #expect(retry?.page == 2)
    }

    @Test("given a stale ticket fails, should not unblock the current load")
    func staleFailureIgnored() {
        var state = ProductListLoad()
        let older = state.beginFirstPage(catalog)
        _ = state.beginFirstPage(ibup)
        let wasCurrent = state.fail(older)
        let loadMore = state.beginNextPage()
        #expect(!wasCurrent) // so the caller leaves the newer load's spinner alone
        #expect(loadMore == nil) // the search's page 1 is still in flight
    }

    // Which query the rows on screen belong to: a reload of that same list keeps
    // them (no flash to empty, scroll kept); any other list starts empty.

    @Test("given page 1 of a query accepted, should report that query's rows as shown")
    func shownAfterAccept() {
        let state = loaded(ibup)
        #expect(state.shownQuery == ibup)
    }

    @Test("given a reload of the shown query in flight, should still report its rows as shown")
    func shownDuringReload() {
        var state = loaded(ibup)
        _ = state.beginFirstPage(ibup)
        #expect(state.shownQuery == ibup)
    }

    @Test("given a stale page 1 for another query, should not mark it shown")
    func staleNotShown() {
        var state = loaded(catalog)
        let old = state.beginFirstPage(ibup)
        _ = state.beginFirstPage(catalog)
        _ = state.accept(old, hasMore: false)
        #expect(state.shownQuery == catalog)
    }

    @Test("given cached rows shown, then rows cleared, should report each")
    func showRows() {
        var state = ProductListLoad()
        state.showRows(of: catalog)
        let afterCache = state.shownQuery
        state.showRows(of: nil)
        #expect(afterCache == catalog)
        #expect(state.shownQuery == nil)
    }
}
