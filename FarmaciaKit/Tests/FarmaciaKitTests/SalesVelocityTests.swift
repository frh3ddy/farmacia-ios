import Foundation
import Testing
@testable import FarmaciaKit

struct SalesVelocityTests {
    private func velocity(_ d30: Int, _ d90: Int, daysSince: Int?) -> SalesVelocity {
        SalesVelocity(lastSoldAt: daysSince.map { _ in Date(timeIntervalSince1970: 0) },
                      unitsLast30d: d30, unitsLast90d: d90, daysSinceLastSale: daysSince)
    }

    @Test("given 12 units in 30 days, last sold 2 days ago, should say 12 vendidas en 30 días · última venta hace 2 días")
    func soldRecently() {
        #expect(velocity(12, 30, daysSince: 2).text == "12 vendidas en 30 días · última venta hace 2 días")
    }

    @Test("given one unit sold today, should use the singular and hoy")
    func oneToday() {
        #expect(velocity(1, 1, daysSince: 0).text == "1 vendida en 30 días · última venta hoy")
    }

    @Test("given a sale yesterday, should say ayer")
    func yesterday() {
        #expect(velocity(3, 3, daysSince: 1).text == "3 vendidas en 30 días · última venta ayer")
    }

    @Test("given nothing in 30 days but 4 in 90, should say Sin ventas en 30 días · 4 en 90 días")
    func quietMonth() {
        #expect(velocity(0, 4, daysSince: 45).text == "Sin ventas en 30 días · 4 en 90 días")
    }

    @Test("given a last sale 200 days ago, should say Sin ventas en 90 días with when")
    func stale() {
        #expect(velocity(0, 0, daysSince: 200).text == "Sin ventas en 90 días · última venta hace 200 días")
    }

    @Test("given no sale ever, should say Sin ventas registradas")
    func neverSold() {
        #expect(velocity(0, 0, daysSince: nil).text == "Sin ventas registradas")
    }

    @Test("given 6 units on hand and no sale in 90 days, should be caution")
    func deadStock() {
        #expect(velocity(0, 0, daysSince: 200).tone(stockOnHand: 6) == .caution)
        #expect(velocity(0, 0, daysSince: nil).tone(stockOnHand: 6) == .caution)
    }

    @Test("given no stock, or a sale in 90 days, should stay neutral")
    func neutral() {
        #expect(velocity(0, 0, daysSince: 200).tone(stockOnHand: 0) == .neutral)
        #expect(velocity(0, 4, daysSince: 45).tone(stockOnHand: 6) == .neutral)
    }

    @Test("given the API's JSON, should decode with an ISO date and nulls")
    func decodes() throws {
        let json = #"{"lastSoldAt":"2026-11-08T15:30:00.000Z","unitsLast30d":12,"unitsLast90d":30,"daysSinceLastSale":2}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let s = try d.singleValueContainer().decode(String.self)
            return try Date(s, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true))
        }
        let v = try decoder.decode(SalesVelocity.self, from: Data(json.utf8))
        #expect(v.unitsLast30d == 12 && v.daysSinceLastSale == 2 && v.lastSoldAt != nil)
        let empty = try decoder.decode(SalesVelocity.self, from: Data(#"{"lastSoldAt":null,"unitsLast30d":0,"unitsLast90d":0,"daysSinceLastSale":null}"#.utf8))
        #expect(empty.text == "Sin ventas registradas")
    }
}
