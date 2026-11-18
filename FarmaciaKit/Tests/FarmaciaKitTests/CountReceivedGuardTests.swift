import Foundation
import Testing
@testable import FarmaciaKit

/// Stock that came in during an open Conteo inicial (a receiving, a return, an opened box,
/// a transfer, Encontrado): marked in No contados, and "Poner todos en 0" leaves it alone
/// (tasks/count-received-guard-epic.md; farmacia-ops 117b834).
struct CountReceivedGuardTests {
    private let zone = TimeZone(identifier: "America/Mexico_City")!
    /// 18 nov 2026, 12:00 in Mexico City.
    private let now = Date(timeIntervalSince1970: 1_795_024_800)

    private func row(_ id: String, units: Int, value: String, receivedAt: Date? = nil) -> UncountedProduct {
        UncountedProduct(productId: id, name: id, units: units, value: value, receivedAt: receivedAt)
    }

    @Test("given an uncounted row with receivedAt (APIClient's date strategy), should decode it; without it (older server), nil")
    func decodesReceivedAt() throws {
        let with = #"{"productId":"a","name":"Jarabe","units":5,"value":"50","receivedAt":"2026-11-12T16:30:00.000Z"}"#
        let without = #"{"productId":"a","name":"Jarabe","units":5,"value":"50","receivedAt":null}"#
        let old = #"{"productId":"a","name":"Jarabe","units":5,"value":"50"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // as APIClient
        #expect(try decoder.decode(UncountedProduct.self, from: Data(with.utf8)).receivedAt != nil)
        #expect(try decoder.decode(UncountedProduct.self, from: Data(without.utf8)).receivedAt == nil)
        #expect(try decoder.decode(UncountedProduct.self, from: Data(old.utf8)).receivedAt == nil)
    }

    @Test("given stock that came in on 12 nov, the row should read 'Entró existencia durante el conteo · 12 nov'")
    func label() {
        let received = row("a", units: 5, value: "50", receivedAt: now.addingTimeInterval(-6 * 86_400))
        #expect(received.receivedNote(now: now, timeZone: zone) == "Entró existencia durante el conteo · 12 nov")
        #expect(row("b", units: 1, value: "1").receivedNote(now: now, timeZone: zone) == nil)
    }

    @Test("given the per-row Poner en 0 (the owner chose it), should send includeReceived true; the bulk one, leave the key out")
    func includeReceivedFlag() throws {
        func body(_ request: StockCountZeroRequest) throws -> [String: Any] {
            try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        }
        #expect(try body(StockCountZeroRequest(productIds: ["a"], includeReceived: true))["includeReceived"] as? Bool == true)
        #expect(try body(StockCountZeroRequest(productIds: ["a"]))["includeReceived"] == nil)
    }

    @Test("given a product skipped as RECEIVED_DURING_COUNT, should say it was left alone to count, not that it failed")
    func receivedSkipped() throws {
        let json = #"[{"productId":"a","ok":true},{"productId":"b","ok":false,"code":"RECEIVED_DURING_COUNT","error":"Entró existencia durante el conteo: cuéntalo antes de ponerlo en 0"}]"#
        let results = try JSONDecoder().decode([StockCountZeroResult].self, from: Data(json.utf8))
        #expect(ZeroOutcome(results).message == "1 producto tuvo entradas durante el conteo; se dejó como estaba: cuéntalo.")
    }

    @Test("given two products with stock in during the count and one already counted, should report each skip")
    func receivedAndCountedSkipped() throws {
        let json = #"[{"productId":"a","ok":false,"code":"RECEIVED_DURING_COUNT","error":"x"},{"productId":"b","ok":false,"code":"RECEIVED_DURING_COUNT","error":"x"},{"productId":"c","ok":false,"code":"ALREADY_COUNTED","error":"x"}]"#
        let results = try JSONDecoder().decode([StockCountZeroResult].self, from: Data(json.utf8))
        #expect(ZeroOutcome(results).message
                == "1 producto ya se había contado; se dejó como estaba.\n2 productos tuvieron entradas durante el conteo; se dejaron como estaban: cuéntalos.")
    }

    @Test("given 3 rows, one with stock in during the count, Poner todos en 0 should zero the other two and say the third stays")
    func zeroAll() {
        let rows = [row("a", units: 5, value: "50"), row("b", units: 2, value: "20", receivedAt: now), row("c", units: 1, value: "10")]
        let all = ZeroAll(rows)
        #expect(all.productIds == ["a", "c"])
        #expect(all.message == "2 productos · 6 unidades · $60.00. Quedarán en 0 como Conteo inicial; no cuenta como merma.\n1 producto con entradas durante el conteo no se pondrá en 0: cuéntalo.")
    }

    @Test("given no rows with stock in during the count, should read as before")
    func zeroAllPlain() {
        #expect(ZeroAll([row("a", units: 5, value: "50")]).message
                == "1 producto · 5 unidades · $50.00. Quedarán en 0 como Conteo inicial; no cuenta como merma.")
    }

    @Test("given only rows with stock in during the count, there should be nothing to zero (the button is off)")
    func zeroAllNothing() {
        let all = ZeroAll([row("a", units: 5, value: "50", receivedAt: now), row("b", units: 1, value: "1", receivedAt: now)])
        #expect(all.productIds.isEmpty)
    }
}
