import Foundation
import Testing
@testable import FarmaciaKit

/// One sales rate everywhere: the detail's sales line and Alertas' reason both read the
/// server's `stockAlert.rate` (units a day over the alerts' window) through one formatter.
struct StockAlertSalesTests {
    private let tz = TimeZone(identifier: "America/Chicago")!
    private let now = Date(timeIntervalSince1970: 1_794_600_000) // 2026-11-13 18:00 CST
    private func daysAgo(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

    private func decode(_ json: String) throws -> StockAlert {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StockAlert.self, from: Data(json.utf8))
    }

    @Test("given rate and lastSoldAt from the server, should decode them; an older server leaves them nil")
    func decodes() throws {
        let alert = try decode(#"{"level":"none","priority":0,"paused":false,"rate":1.25,"lastSoldAt":"2026-11-11T20:00:00Z"}"#)
        #expect(alert.rate == 1.25)
        #expect(alert.lastSoldAt == ISO8601DateFormatter().date(from: "2026-11-11T20:00:00Z"))
        // Ops sends milliseconds; the app's decoder (.iso8601, as in APIClient) must read them.
        let ms = try decode(#"{"level":"none","rate":0,"lastSoldAt":"2026-11-11T20:00:00.000Z"}"#)
        #expect(ms.lastSoldAt == alert.lastSoldAt)
        let old = try decode(#"{"level":"out","priority":2,"paused":false}"#)
        #expect(old.rate == nil)
        #expect(old.lastSoldAt == nil)
    }

    @Test("given a cached alert, should keep rate and lastSoldAt")
    func cacheRoundTrip() {
        let alert = StockAlert(level: .low, priority: 0.25, rate: 1, lastSoldAt: daysAgo(2))
        #expect(StockAlert(cacheData: alert.cacheData) == alert)
    }

    @Test("given 1 a day, last sold 2 days ago, should say Vende ~1 al día · última venta hace 2 días")
    func sellingLine() {
        let alert = StockAlert(level: .none, rate: 1, lastSoldAt: daysAgo(2))
        #expect(alert.salesLine(now: now, timeZone: tz) == "Vende ~1 al día · última venta hace 2 días")
    }

    @Test("given nothing sold in the window, should say Sin ventas recientes with the last sale; never sold, Sin ventas registradas")
    func quietLines() {
        #expect(StockAlert(level: .none, rate: 0, lastSoldAt: daysAgo(200)).salesLine(now: now, timeZone: tz)
                == "Sin ventas recientes · última venta hace 200 días")
        #expect(StockAlert(level: .none, rate: 0).salesLine(now: now, timeZone: tz) == "Sin ventas registradas")
    }

    @Test("given no stats (an older server, a new product), should give no sales line")
    func noStats() {
        #expect(StockAlert(level: .none).salesLine(now: now, timeZone: tz) == nil)
    }

    @Test("given the same product, the detail's rate and Alertas' reason should say the same rate")
    func detailMatchesAlertas() throws {
        let out = StockAlert(level: .out, priority: 2.8, rate: 2.8, lastSoldAt: daysAgo(3))
        let line = try #require(out.salesLine(now: now, timeZone: tz))
        let reason = try #require(out.reasonText(quantity: 0))
        #expect(line.hasPrefix(reason))
        let low = StockAlert(level: .low, priority: 0.25, rate: 1, lastSoldAt: daysAgo(1))
        let lowReason = try #require(low.reasonText(quantity: 4))
        #expect(lowReason == "Vende ~1 al día · alcanza para ~4 días")
        #expect(try #require(low.salesLine(now: now, timeZone: tz)).hasPrefix("Vende ~1 al día"))
    }
}
