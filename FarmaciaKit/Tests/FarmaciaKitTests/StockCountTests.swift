import Foundation
import Testing
@testable import FarmaciaKit

struct CountSaveTests {
    @Test("given a Conteo inicial and a count equal to stock, should save, since it marks the product counted")
    func openingCountMatch() {
        #expect(CountSave.action(matches: true, inOpeningCount: true) == .save)
    }

    @Test("given a Corrección de Conteo equal to stock, should close without saving, as today")
    func correctionMatch() {
        #expect(CountSave.action(matches: true, inOpeningCount: false) == .closeWithoutSaving)
    }

    @Test("given a count that differs from stock, should save either way", arguments: [true, false])
    func differs(inOpeningCount: Bool) {
        #expect(CountSave.action(matches: false, inOpeningCount: inOpeningCount) == .save)
    }
}

struct StockCountSessionTests {
    @Test("given the active-count response with milliseconds, should decode with APIClient's own strategy")
    func decodes() throws {
        let json = #"{"id":"c1","locationId":"l1","startedAt":"2026-11-05T15:00:00.000Z","startedBy":"e1","endedAt":null,"endedBy":null,"countedProducts":12}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // as APIClient
        let session = try decoder.decode(StockCountSession.self, from: Data(json.utf8))
        #expect(session.id == "c1")
        #expect(session.countedProducts == 12)
    }

    @Test("given an API from before Conteo inicial (404), should read as no count open, so counts aren't blocked")
    func oldServer() {
        #expect(StockCountSession.noCountOnServer(NetworkError.httpError(statusCode: 404, message: nil)))
        #expect(!StockCountSession.noCountOnServer(NetworkError.serverError(message: "x")))
        #expect(!StockCountSession.noCountOnServer(NetworkError.httpError(statusCode: 403, message: nil)))
    }
}

struct UncountedSummaryTests {
    private let rows = [
        UncountedProduct(productId: "a", name: "Jarabe", units: 5, value: "50"),
        UncountedProduct(productId: "b", name: "Aguja", units: 2, value: "20.5"),
        UncountedProduct(productId: "c", name: "Gasa", units: 1, value: "9.5"),
    ]

    @Test("given 3 products with 5, 2 and 1 units worth $80, should read the totals")
    func totals() {
        #expect(UncountedSummary(rows).text == "3 productos · 8 unidades · $80.00")
    }

    @Test("given one product with one unit, should use the singular")
    func singular() {
        #expect(UncountedSummary([UncountedProduct(productId: "a", name: "Aguja", units: 1, value: "2")]).text
                == "1 producto · 1 unidad · $2.00")
    }
}

struct StockCountEntryRequestTests {
    @Test("given the form's request id, should send it, so a retry after commit isn't counted twice")
    func sendsRequestId() throws {
        let body = StockCountEntryRequest(productId: "p1", countedQuantity: 5, unitCost: nil, clientRequestId: "req-1")
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        #expect(json["clientRequestId"] as? String == "req-1")
        #expect(json["countedQuantity"] as? Int == 5)
    }
}

struct ZeroOutcomeTests {
    private func result(_ json: String) throws -> StockCountZeroResult {
        try JSONDecoder().decode(StockCountZeroResult.self, from: Data(json.utf8))
    }

    @Test("given every product zeroed, should have nothing to say")
    func allZeroed() throws {
        #expect(ZeroOutcome([try result(#"{"productId":"a","ok":true}"#)]).message == nil)
    }

    @Test("given a product counted after the list loaded, should say it was skipped, not that it failed")
    func skipped() throws {
        let outcome = ZeroOutcome([
            try result(#"{"productId":"a","ok":true}"#),
            try result(#"{"productId":"b","ok":false,"code":"ALREADY_COUNTED","error":"Ya se contó en este conteo"}"#),
        ])
        #expect(outcome.message == "1 producto ya se había contado; se dejó como estaba.")
    }

    @Test("given a real failure and two skips, should report both")
    func failedAndSkipped() throws {
        let outcome = ZeroOutcome([
            try result(#"{"productId":"a","ok":false,"error":"Las existencias cambiaron"}"#),
            try result(#"{"productId":"b","ok":false,"code":"ALREADY_COUNTED","error":"x"}"#),
            try result(#"{"productId":"c","ok":false,"code":"ALREADY_COUNTED","error":"x"}"#),
        ])
        #expect(outcome.message == "1 producto no se pudo poner en 0: Las existencias cambiaron\n2 productos ya se habían contado; se dejaron como estaban.")
    }
}

struct StockCountEntryResultTests {
    private func decode(_ json: String) throws -> StockCountEntryResult {
        try JSONDecoder().decode(StockCountEntryResult.self, from: Data(json.utf8))
    }

    @Test("given a count Square didn't take, should warn with the reason and where to retry")
    func squareFailed() throws {
        let result = try decode(#"{"entry":{},"adjustment":{},"squareSync":{"synced":false,"error":"Producto no vinculado"}}"#)
        #expect(result.squareWarning == "Conteo guardado, pero no se sincronizó con Square: Producto no vinculado. Puedes reintentar desde el historial.")
    }

    @Test("given a synced count, a match with no adjustment, or a replay, should have nothing to say",
          arguments: [#"{"squareSync":{"synced":true}}"#, #"{"adjustment":null}"#, #"{}"#])
    func nothingToSay(json: String) throws {
        #expect(try decode(json).squareWarning == nil)
    }
}

struct ZeroBatchTests {
    @Test("given 120 products, should send them 25 at a time so no request runs past the timeout")
    func batches() {
        let ids = (1...120).map(String.init)
        let batches = ZeroBatch.split(ids)
        #expect(batches.map(\.count) == [25, 25, 25, 25, 20])
        #expect(batches.flatMap { $0 } == ids)
    }

    @Test("given a run stopped by a failed batch, should say what was done and why it stopped")
    func stopped() throws {
        let done = try JSONDecoder().decode([StockCountZeroResult].self, from: Data(#"[{"productId":"a","ok":true}]"#.utf8))
        #expect(ZeroOutcome(done, stoppedBy: "Sin conexión").message == "Se detuvo: Sin conexión. Los que faltan siguen en la lista.")
    }
}
