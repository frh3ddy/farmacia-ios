import Foundation
import Testing
@testable import FarmaciaKit

/// Per-product stock alerts from the API (docs/stock-alerts-design.md): only regular
/// sellers alert, and a paused product never does.
struct StockAlertTests {
    private func decode(_ json: String) throws -> StockAlert {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // same as APIClient
        return try decoder.decode(StockAlert.self, from: Data(json.utf8))
    }

    @Test("given an out alert from the API, should decode with level out")
    func decodesOut() throws {
        let alert = try decode(#"{"level":"out","priority":2.5,"paused":false,"zeroSince":"2026-11-08T15:30:00.000Z"}"#) // the API sends milliseconds
        #expect(alert.level == .out)
        #expect(alert.priority == 2.5)
        #expect(!alert.paused)
        #expect(alert.zeroSince == Date(timeIntervalSince1970: 1_794_151_800))
    }

    @Test("given a paused alert, should decode its reason")
    func decodesPaused() throws {
        let alert = try decode(#"{"level":"none","priority":0,"paused":true,"pauseReason":"SUPPLIER_UNAVAILABLE"}"#)
        #expect(alert.paused)
        #expect(alert.pauseReason == .supplierUnavailable)
        #expect(alert.zeroSince == nil)
    }

    @Test("given no priority or paused, should read them as 0 and not paused")
    func defaults() throws {
        let alert = try decode(#"{"level":"low"}"#)
        #expect(alert.priority == 0)
        #expect(!alert.paused)
    }

    @Test("given a level or reason this app doesn't know, should still decode (the product list must not fail)")
    func unknownValues() throws {
        let alert = try decode(#"{"level":"critical","priority":1,"paused":true,"pauseReason":"SEASONAL"}"#)
        #expect(alert.level == .none)
        #expect(alert.pauseReason == nil)
    }
}

struct PauseReasonTests {
    @Test("given REPLACED_BY_EQUIVALENT, should say Reemplazado por equivalente and require a product")
    func replaced() {
        #expect(PauseReason.replacedByEquivalent.label == "Reemplazado por equivalente")
        #expect(PauseReason.replacedByEquivalent.requiresProduct)
        #expect(!PauseReason.supplierUnavailable.requiresProduct)
    }

    @Test("given every reason, should have a label and the API's raw value")
    func labels() {
        #expect(PauseReason.allCases.map(\.label) == ["Proveedor sin surtido", "Reemplazado por equivalente", "Se vende poco", "Otro"])
        #expect(PauseReason.allCases.map(\.rawValue) == ["SUPPLIER_UNAVAILABLE", "REPLACED_BY_EQUIVALENT", "SLOW_MOVER", "OTHER"])
    }
}

/// The badge on rows, cards and the detail: from the API's alert when it sends one,
/// else today's fixed cutoffs.
struct StockLevelAlertTests {
    @Test("given level out, should be Agotado with critical tone")
    func out() {
        let level = StockLevel(quantity: 0, alert: StockAlert(level: .out, priority: 2))
        #expect(level == .out)
        #expect(level.label == "Agotado")
        #expect(level.tone == .critical)
    }

    @Test("given 0 on hand but no alert (not a regular seller), should say Agotado without alarm")
    func emptyNotAlerting() {
        let level = StockLevel(quantity: 0, alert: StockAlert(level: .none))
        #expect(level == .empty)
        #expect(level.label == "Agotado")
        #expect(level.tone == .neutral)
    }

    @Test("given level low, should be Bajo with caution tone; given 2 on hand and no alert, nothing")
    func low() {
        #expect(StockLevel(quantity: 3, alert: StockAlert(level: .low)) == .low)
        let quiet = StockLevel(quantity: 2, alert: StockAlert(level: .none))
        #expect(quiet == .ok)
        #expect(quiet.label == nil)
    }

    @Test("given a paused product, should say Pausado with its reason, neutral, even at 0")
    func paused() {
        let level = StockLevel(quantity: 0, alert: StockAlert(level: .none, paused: true, pauseReason: .supplierUnavailable))
        #expect(level == .paused(.supplierUnavailable))
        #expect(level.label == "Pausado · Proveedor sin surtido")
        #expect(level.tone == .neutral)
        #expect(StockLevel.paused(nil).label == "Pausado")
    }

    @Test("given no alert (old server), should keep the fixed cutoffs", arguments: [(0, StockLevel.out), (5, .low), (10, .ok)])
    func fallback(quantity: Int, expected: StockLevel) {
        #expect(StockLevel(quantity: quantity, alert: nil) == expected)
    }
}

struct ZeroSinceTextTests {
    private let mx = TimeZone(identifier: "America/Mexico_City")!
    private let now = Date(timeIntervalSince1970: 1_794_151_800) // 8 nov 2026, 9:30 a.m. in Mexico City

    @Test("given zeroSince 3 days ago, should say Agotado hace 3 días")
    func threeDays() {
        let alert = StockAlert(level: .out, zeroSince: now.addingTimeInterval(-3 * 86_400))
        #expect(alert.zeroSinceText(now: now, timeZone: mx) == "Agotado hace 3 días")
    }

    @Test("given zeroSince today, should say Agotado hoy; given none, nil")
    func todayAndNone() {
        #expect(StockAlert(level: .out, zeroSince: now).zeroSinceText(now: now, timeZone: mx) == "Agotado hoy")
        #expect(StockAlert(level: .out).zeroSinceText(now: now, timeZone: mx) == nil)
    }
}
