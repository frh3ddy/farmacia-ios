import Foundation
import Testing
@testable import FarmaciaKit

/// Alertas' ranked lists (stock alerts O6): GET /products?filter=outAlert|lowAlert, highest lost sales first.
struct AlertListTests {
    private func counts(_ json: String) throws -> ProductCountsResponse {
        try JSONDecoder().decode(ProductCountsResponse.self, from: Data(json.utf8))
    }

    @Test("given the Sin Stock list, should ask the server for the alerting products only (outAlert)")
    func filters() {
        let out = ProductListQuery(locationId: "loc", alert: .out)
        #expect(out.params(page: 2, limit: 50) == ["locationId": "loc", "filter": "outAlert", "page": "2", "limit": "50"])
        #expect(ProductListQuery(locationId: "loc", alert: .low).params(page: 1, limit: 50)["filter"] == "lowAlert")
        #expect(ProductListQuery(locationId: "loc", alert: .lowMargin).params(page: 1, limit: 50)["filter"] == "lowMargin")
        #expect(!out.isCatalog)
        #expect(out.alert == .out)
    }

    @Test("given Sin Stock's page 2 still loading when Stock Bajo is picked, should drop it")
    func switchingDropsLatePage() throws {
        var load = ProductListLoad()
        _ = load.accept(load.beginFirstPage(ProductListQuery(locationId: "loc", alert: .out)), hasMore: true)
        let next = load.beginNextPage()
        let latePage = try #require(next)
        let low = load.beginFirstPage(ProductListQuery(locationId: "loc", alert: .low))
        let lateAccepted = load.accept(latePage, hasMore: false)
        #expect(!lateAccepted)
        let lowAccepted = load.accept(low, hasMore: false)
        #expect(lowAccepted)
    }

    @Test("given Alertas' Sin Stock, should say it only counts regular sellers not paused (Productos' Sin Stock counts every 0)")
    func notes() {
        #expect(AlertList.out.note == "Solo productos que se venden seguido y no están pausados. Primero los que más ventas pierden.")
        #expect(AlertList.low.note == "Solo productos que se venden seguido y no están pausados. Primero los que se acaban antes.")
        #expect(AlertList.lowMargin.note == nil)
    }

    @Test("given counts with outAlert, Sin Stock should count it, not every product at 0")
    func outCount() throws {
        let c = try counts(#"{"total":46,"outOfStock":6,"outAlert":2,"lowStock":3,"lowMargin":4,"synced":44,"local":2}"#)
        #expect(AlertList.out.count(c) == 2)
        #expect(AlertList.low.count(c) == 3)
        #expect(AlertList.lowMargin.count(c) == 4)
    }

    @Test("given a server without outAlert, Sin Stock should fall back to outOfStock")
    func outCountOldServer() throws {
        let c = try counts(#"{"total":46,"outOfStock":6,"lowStock":3,"synced":44,"local":2}"#)
        #expect(AlertList.out.count(c) == 6)
        #expect(AlertList.lowMargin.count(c) == nil) // a cashier's counts
    }

    @Test("given a row paused or restocked from the detail, should leave Sin Stock / Stock Bajo; Margen Bajo keeps it")
    func keeps() {
        let paused = StockAlert(level: .none, paused: true)
        #expect(AlertList.out.keeps(StockAlert(level: .out)))
        #expect(!AlertList.out.keeps(paused))
        #expect(!AlertList.out.keeps(StockAlert(level: .low)))
        #expect(AlertList.low.keeps(StockAlert(level: .low)))
        #expect(!AlertList.low.keeps(nil))
        #expect(AlertList.lowMargin.keeps(paused))
    }

    @Test("given a cashier, should leave Margen Bajo out (it's worked out from cost)")
    func visible() {
        #expect(AlertList.visible(canViewCosts: false) == [.out, .low])
        #expect(AlertList.visible(canViewCosts: true) == [.out, .low, .lowMargin])
    }
}

/// The reason to care on an Alertas row, from the API's priority:
/// out → units sold a day; low → units a day ÷ units on hand.
struct StockAlertReasonTests {
    @Test("given an out alert selling 3 a day, should say Vende ~3 al día (the row's badge already says since when)")
    func out() {
        let alert = StockAlert(level: .out, priority: 2.8, zeroSince: Date(timeIntervalSince1970: 1_794_000_000))
        #expect(alert.reasonText(quantity: 0) == "Vende ~3 al día")
    }

    @Test("given a slow seller, should count by week, or by month below 1 a week")
    func slowRates() {
        #expect(StockAlert(level: .out, priority: 0.3).reasonText(quantity: 0) == "Vende ~2 a la semana")
        #expect(StockAlert(level: .out, priority: 0.1).reasonText(quantity: 0) == "Vende ~3 al mes")
        #expect(StockAlert(level: .out, priority: 0.01).reasonText(quantity: 0) == "Vende ~1 al mes")
    }

    @Test("given a low alert with 4 on hand selling 1 a day, should say vende ~1 al día · alcanza para ~4 días")
    func low() {
        let alert = StockAlert(level: .low, priority: 0.25) // 1 a day ÷ 4 on hand
        #expect(alert.reasonText(quantity: 4) == "Vende ~1 al día · alcanza para ~4 días")
    }

    @Test("given a low alert that lasts under a day, should say alcanza para menos de 1 día; 1 day, singular")
    func lowShort() {
        #expect(StockAlert(level: .low, priority: 2.5).reasonText(quantity: 2)
                == "Vende ~5 al día · alcanza para menos de 1 día")
        #expect(StockAlert(level: .low, priority: 1).reasonText(quantity: 3)
                == "Vende ~3 al día · alcanza para ~1 día")
    }

    @Test("given no alert, a paused product or no rate, should give no reason")
    func none() {
        #expect(StockAlert(level: .none).reasonText(quantity: 0) == nil)
        #expect(StockAlert(level: .out, priority: 0).reasonText(quantity: 0) == nil)
    }
}
