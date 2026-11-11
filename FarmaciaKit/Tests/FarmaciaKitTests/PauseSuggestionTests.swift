import Foundation
import Testing
@testable import FarmaciaKit

/// Pause suggestions from sales and stock history (GET /inventory/pause-suggestions).
/// Each row shows its evidence so a person can decide; nothing is paused by itself.
struct PauseSuggestionTests {
    private let mx = TimeZone(identifier: "America/Mexico_City")!

    private func decode(_ json: String) throws -> PauseSuggestion {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // same as APIClient
        return try decoder.decode(PauseSuggestion.self, from: Data(json.utf8))
    }

    @Test("given NO_SALES_AT_ZERO, last sold 3 mar 2026, 0 in 90 days, 120 days at 0, should list that evidence")
    func noSalesAtZero() throws {
        let s = try decode(#"{"product":{"id":"p1","name":"Ambroxol jarabe"},"kind":"NO_SALES_AT_ZERO","lastSoldAt":"2026-03-03T18:00:00Z","unitsInWindow":0,"daysAtZero":120,"stockOuts":1}"#)
        #expect(s.id == "p1-NO_SALES_AT_ZERO")
        #expect(s.product.name == "Ambroxol jarabe")
        #expect(s.reasonText(timeZone: mx) == "Sin ventas desde 3 mar 2026 · 0 en 90 días · 120 días en 0")
    }

    @Test("given it never sold, should say Sin ventas registradas")
    func neverSold() throws {
        let s = try decode(#"{"product":{"id":"p1","name":"X"},"kind":"NO_SALES_AT_ZERO","unitsInWindow":0,"daysAtZero":1,"stockOuts":0}"#)
        #expect(s.reasonText(timeZone: mx) == "Sin ventas registradas · 1 día en 0")
    }

    @Test("given SLOW_WITH_STOCKOUTS, should list units, stock-outs and days at 0")
    func slow() throws {
        let s = try decode(#"{"product":{"id":"p1","name":"X"},"kind":"SLOW_WITH_STOCKOUTS","lastSoldAt":"2026-10-01T18:00:00Z","unitsInWindow":2,"daysAtZero":45,"stockOuts":3}"#)
        #expect(s.reasonText(timeZone: mx) == "2 vendidas en 90 días · se agotó 3 veces · 45 días en 0")
        let one = try decode(#"{"product":{"id":"p1","name":"X"},"kind":"SLOW_WITH_STOCKOUTS","unitsInWindow":1,"daysAtZero":30,"stockOuts":1}"#)
        #expect(one.reasonText(timeZone: mx) == "1 vendida en 90 días · se agotó 1 vez · 30 días en 0")
    }

    @Test("given EQUIVALENT_SELLING, should name the equivalent and what it sold")
    func equivalent() throws {
        let s = try decode(#"{"product":{"id":"p1","name":"Paracetamol MK"},"kind":"EQUIVALENT_SELLING","unitsInWindow":0,"daysAtZero":30,"stockOuts":1,"equivalent":{"id":"p2","name":"Paracetamol Genfar","unitsSince":14}}"#)
        #expect(s.reasonText(timeZone: mx) == "Su equivalente Paracetamol Genfar vendió 14 desde que se agotó · 30 días en 0")
    }

    @Test("given a 60-day window from the store's settings, should say so")
    func window() throws {
        let s = try decode(#"{"product":{"id":"p1","name":"X"},"kind":"SLOW_WITH_STOCKOUTS","unitsInWindow":2,"daysAtZero":45,"stockOuts":3}"#)
        #expect(s.reasonText(windowDays: 60, timeZone: mx) == "2 vendidas en 60 días · se agotó 3 veces · 45 días en 0")
    }
}
