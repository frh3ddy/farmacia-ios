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

struct CountSaveValidityTests {
    @Test("given a Conteo inicial and a count equal to stock, should be savable; given a correction, not")
    func matchSavableOnlyInOpeningCount() {
        #expect(CountSave.canSave(change: nil, matches: true, inOpeningCount: true))
        #expect(!CountSave.canSave(change: nil, matches: true, inOpeningCount: false))
    }

    @Test("given a count that changes the stock, should be savable either way; with no count, neither", arguments: [true, false])
    func change(inOpeningCount: Bool) {
        #expect(CountSave.canSave(change: -2, matches: false, inOpeningCount: inOpeningCount))
        #expect(!CountSave.canSave(change: nil, matches: false, inOpeningCount: inOpeningCount))
    }

    @Test("given a Conteo inicial and stock 12, the one-tap Sin cambios should save 12")
    func quickMatch() {
        #expect(CountSave.quickMatch(liveStock: 12, inOpeningCount: true) == 12)
    }

    @Test("given a correction, or stock not loaded yet, there should be no one-tap Sin cambios")
    func noQuickMatch() {
        #expect(CountSave.quickMatch(liveStock: 12, inOpeningCount: false) == nil)
        #expect(CountSave.quickMatch(liveStock: nil, inOpeningCount: true) == nil)
    }
}

struct CountLotsTests {
    private let jan = MonthYear(year: 2027, month: 1)
    private let mar = MonthYear(year: 2027, month: 3)

    @Test("given a row with 4 and ene-2027, should count, lote or not; without caducidad, should not")
    func rowCompleteness() {
        #expect(CountLot(quantity: 4, expiry: jan).isComplete)
        #expect(CountLot(quantity: 4, expiry: jan, batchNumber: "A12").isComplete)
        #expect(!CountLot(quantity: 4, batchNumber: "A12").isComplete)
        #expect(!CountLot(quantity: 4).isComplete)
        #expect(CountLot().isBlank)
    }

    @Test("given lots 4 + 6 and a count of 10, should match")
    func matches() {
        #expect(CountLots([CountLot(quantity: 4, expiry: jan), CountLot(quantity: 6, expiry: mar)]).check(counted: 10) == .matches)
    }

    @Test("given no lots, or only blank rows, there's nothing to check")
    func none() {
        #expect(CountLots([]).check(counted: 10) == .none)
        #expect(CountLots([CountLot()]).check(counted: 10) == .none)
    }

    @Test("given lots over the count, should block with by how much")
    func over() {
        let lots = CountLots([CountLot(quantity: 4, expiry: jan), CountLot(quantity: 8, expiry: mar)])
        #expect(lots.check(counted: 10) == .mismatch("Los lotes suman 12 de 10: sobran 2"))
    }

    @Test("given lots under the count, should allow it and say how many units stay without a lot")
    func under() {
        let lots = CountLots([CountLot(quantity: 4, expiry: jan), CountLot(quantity: 3, expiry: mar)])
        #expect(lots.check(counted: 10) == .partial("3 unidades sin lote"))
        #expect(CountLots([CountLot(quantity: 9, expiry: jan)]).check(counted: 10) == .partial("1 unidad sin lote"))
    }

    @Test("given a lot without caducidad (even with a lote), should point it out")
    func incompleteRow() {
        let lots = CountLots([CountLot(quantity: 4, expiry: jan), CountLot(quantity: 6, batchNumber: "A12")])
        #expect(lots.check(counted: 10) == .mismatch("Cada lote necesita su caducidad"))
    }

    @Test("given ene-2027 × 4 with lote A12, should send it like receiving does")
    func request() throws {
        let mx = try #require(TimeZone(identifier: "America/Mexico_City"))
        let lots = CountLots([CountLot(quantity: 4, expiry: jan, batchNumber: " A12 "), CountLot()]).requestLots(timeZone: mx)
        #expect(lots == [StockCountLot(quantity: 4, expiryDate: "2027-01-01", batchNumber: "A12")])
    }

    @Test("given no lots, the entry should carry no lots key at all")
    func noLotsKey() throws {
        let body = StockCountEntryRequest(productId: "p1", countedQuantity: 5, unitCost: nil, clientRequestId: "r",
                                          lots: CountLots([]).requestLots())
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])
        #expect(json["lots"] == nil)
    }
}

struct CountPrefillTests {
    private let jan = MonthYear(year: 2027, month: 1)

    @Test("given stock 64 loads and nothing typed, the stepper should start at 64")
    func startsAtStock() {
        #expect(CountSave.startValue(liveStock: 64, typed: nil) == 64)
    }

    @Test("given the user already typed 60, a stock (re)load should not overwrite it")
    func keepsTyped() {
        #expect(CountSave.startValue(liveStock: 64, typed: 60) == 60)
        #expect(CountSave.startValue(liveStock: nil, typed: nil) == nil)
    }

    @Test("given the product's current lots, should pre-fill rows with month and lote")
    func prefillRows() throws {
        let current = try JSONDecoder().decode([CurrentLot].self, from: Data(#"[{"quantity":4,"expiryDate":"2027-01-01","batchNumber":"A12"},{"quantity":6,"expiryDate":"2027-03-15","batchNumber":null}]"#.utf8))
        let rows = current.map(\.row)
        #expect(rows.map(\.quantity) == [4, 6])
        #expect(rows.map(\.expiry) == [jan, MonthYear(year: 2027, month: 3)])
        #expect(rows.map(\.batchNumber) == ["A12", ""])
    }

    @Test("given pre-filled lots left untouched, should send no lots and check nothing, even if they don't add up")
    func untouchedPrefill() {
        let prefilled = [CountLot(quantity: 4, expiry: jan)]
        let lots = CountLots(prefilled, original: prefilled)
        #expect(lots.requestLots() == nil)
        #expect(lots.check(counted: 64) == .none)
    }

    @Test("given a pre-filled lot edited, should check and send all the rows")
    func editedPrefill() {
        let prefilled = [CountLot(quantity: 4, expiry: jan)]
        var edited = prefilled
        edited[0].quantity = 5
        let lots = CountLots(edited, original: prefilled)
        #expect(lots.check(counted: 5) == .matches)
        #expect(lots.requestLots()?.map(\.quantity) == [5])
    }

    @Test("given Sin cambios with edited lots over the stock, should block it; under the stock is fine")
    func quickMatchWithLots() {
        #expect(CountLots([CountLot(quantity: 12, expiry: jan)]).quickMatchBlocker(stock: 10) == "Los lotes suman 12 de 10: sobran 2")
        #expect(CountLots([CountLot(quantity: 4, expiry: jan)]).quickMatchBlocker(stock: 10) == nil)
        #expect(CountLots([]).quickMatchBlocker(stock: 10) == nil)
    }
}

struct CountLotScanTests {
    private let today = MonthYear(year: 2026, month: 11)

    @Test("given a scan with lote and caducidad, should fill both and keep the row's quantity")
    func fillsBoth() {
        let scan = LotScan(lines: ["LOTE: A12B", "CAD: 03/2028"], barcodes: [], today: today)
        let row = CountLot(quantity: 4).applying(scan)
        #expect(row.batchNumber == scan.lot ?? "")
        #expect(row.expiry == scan.expiry)
        #expect(row.quantity == 4)
        #expect(scan.isComplete)
    }

    @Test("given a scan that only read the lote, should keep the caducidad already picked")
    func keepsWhatScanMissed() {
        let picked = MonthYear(year: 2027, month: 1)
        let scan = LotScan(lines: ["LOTE: A12B"], barcodes: [], today: today)
        let row = CountLot(quantity: 4, expiry: picked).applying(scan)
        #expect(row.expiry == picked)
        #expect(!row.batchNumber.isEmpty)
    }
}

struct CountedEntryTests {
    private let mx = TimeZone(identifier: "America/Mexico_City")!

    private func decode(_ json: String) throws -> CountedEntry {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // as APIClient
        return try decoder.decode(CountedEntry.self, from: Data(json.utf8))
    }

    @Test("given a product counted at 10 on Nov 5 by Fredy, should say so")
    func note() throws {
        let entry = try decode(#"{"countedQuantity":10,"countedAt":"2026-11-05T18:00:00.000Z","countedByName":"Fredy"}"#)
        #expect(entry.note(timeZone: mx) == "Ya contado en este conteo: 10 · 5 nov, Fredy")
    }

    @Test("given a late-evening count in Mexico City, should show the local day, not the UTC one")
    func localDay() throws {
        let entry = try decode(#"{"countedQuantity":3,"countedAt":"2026-11-06T04:30:00.000Z","countedByName":null}"#)
        #expect(entry.note(timeZone: mx) == "Ya contado en este conteo: 3 · 5 nov")
    }
    @Test("given the earlier count's Razón and Notas, should show them, so a matching count's notes aren't lost")
    func remarks() throws {
        let entry = try decode(#"{"countedQuantity":3,"countedAt":"2026-11-05T18:00:00.000Z","countedByName":null,"reason":"Caja rota","notes":"en bodega"}"#)
        #expect(entry.remarks == "Caja rota · en bodega")
    }

    @Test("given a server without them, or empty ones, should show nothing")
    func noRemarks() throws {
        #expect(try decode(#"{"countedQuantity":3,"countedAt":"2026-11-05T18:00:00.000Z","countedByName":null}"#).remarks == nil)
        #expect(try decode(#"{"countedQuantity":3,"countedAt":"2026-11-05T18:00:00.000Z","countedByName":null,"reason":null,"notes":""}"#).remarks == nil)
    }
}

struct CountLotsSplitTests {
    private let jan = MonthYear(year: 2027, month: 1)

    @Test("given one lot, should take the whole count")
    func one() {
        let rows = CountLots.split(10, across: [CountLot(quantity: 3, expiry: jan)])
        #expect(rows.map(\.quantity) == [10])
        #expect(rows[0].expiry == jan)
    }

    @Test("given several lots, should split evenly, the remainder to the first ones, adding up to the count")
    func several() {
        #expect(CountLots.split(10, across: [CountLot(), CountLot()]).map(\.quantity) == [5, 5])
        #expect(CountLots.split(10, across: [CountLot(), CountLot(), CountLot()]).map(\.quantity) == [4, 3, 3])
        #expect(CountLots.split(1, across: [CountLot(), CountLot()]).map(\.quantity) == [1, 0])
    }

    @Test("given no lots or no count, should leave the rows as they are")
    func nothing() {
        #expect(CountLots.split(10, across: []).isEmpty)
        let rows = [CountLot(quantity: 2)]
        #expect(CountLots.split(nil, across: rows) == rows)
    }
}

struct CountLotsSplitKeepingTests {
    @Test("given a lot edited by hand, should keep it and split the rest of the count over the others")
    func keepsEdited() {
        let edited = CountLot(quantity: 6)
        let rows = CountLots.split(10, across: [edited, CountLot(), CountLot()], keeping: [edited.id])
        #expect(rows.map(\.quantity) == [6, 2, 2])
    }

    @Test("given edited lots over the count, should leave the others at 0, so the footer shows the mismatch")
    func editedOver() {
        let edited = CountLot(quantity: 12)
        #expect(CountLots.split(10, across: [edited, CountLot()], keeping: [edited.id]).map(\.quantity) == [12, 0])
    }

    @Test("given every lot edited, should change nothing")
    func allEdited() {
        let rows = [CountLot(quantity: 6), CountLot(quantity: 4)]
        #expect(CountLots.split(20, across: rows, keeping: Set(rows.map(\.id))) == rows)
    }
}

struct LotSplitTests {
    @Test("given the field echoing the same count back, should leave the lots as they are")
    func echo() {
        var split = LotSplit([CountLot(quantity: 6), CountLot(quantity: 4)])
        split.countChanged(from: 10, to: 10)
        #expect(split.rows.map(\.quantity) == [6, 4])
    }

    @Test("given a count typed after clearing the field (nil → 8), should split it")
    func typedAfterClearing() {
        var split = LotSplit([CountLot(), CountLot()])
        split.countChanged(from: nil, to: 8)
        #expect(split.rows.map(\.quantity) == [4, 4])
    }

    @Test("given the quantity field writing back the same value, should not pin the lot")
    func sameValueNotPinned() {
        var split = LotSplit([CountLot(quantity: 10)])
        split.setQuantity(10, of: split.rows[0].id)
        split.add(CountLot(), count: 10)
        #expect(split.rows.map(\.quantity) == [5, 5])
    }

    @Test("given a lot edited by hand, should keep it when a lot is added or the count changes")
    func editedKept() {
        var split = LotSplit([CountLot(quantity: 5), CountLot(quantity: 5)])
        split.setQuantity(6, of: split.rows[0].id)
        split.add(CountLot(), count: 10)
        #expect(split.rows.map(\.quantity) == [6, 2, 2])
        split.countChanged(from: 10, to: 12)
        #expect(split.rows.map(\.quantity) == [6, 3, 3])
    }

    @Test("given a lot removed, should split the count over the rest")
    func removed() {
        var split = LotSplit([CountLot(), CountLot(), CountLot()])
        split.countChanged(from: 0, to: 9)
        split.remove(atOffsets: [0], count: 9)
        #expect(split.rows.map(\.quantity) == [5, 4])
    }
}

// MARK: - Workflow review fixes

struct CountLotsZeroQuantityTests {
    private let jan = MonthYear(year: 2027, month: 1)
    private let mar = MonthYear(year: 2027, month: 3)

    @Test("given a lot split down to 0 units, should ignore it, not block Guardar for a caducidad it has")
    func zeroLotIgnored() {
        let lots = CountLots([CountLot(quantity: 1, expiry: jan), CountLot(quantity: 0, expiry: mar)])
        #expect(lots.check(counted: 1) == .matches)
        #expect(lots.requestLots()?.count == 1)
    }

    @Test("given lots over the count, should say so before asking for a caducidad")
    func overBeforeCaducidad() {
        let lots = CountLots([CountLot(quantity: 12, expiry: jan), CountLot(quantity: 1)])
        #expect(lots.check(counted: 10) == .mismatch("Los lotes suman 13 de 10: sobran 3"))
    }

    @Test("given a lot with units and no caducidad within the count, should ask for its caducidad")
    func stillAsksCaducidad() {
        #expect(CountLots([CountLot(quantity: 4)]).check(counted: 10) == .mismatch("Cada lote necesita su caducidad"))
    }
}

struct StockCountRequestStoreTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any]
    }

    @Test("given a count entry, should name the store and send Razón and Notas trimmed")
    func entryBody() throws {
        let body = try json(StockCountEntryRequest(productId: "p1", countedQuantity: 5, unitCost: nil, clientRequestId: "r",
                                                   locationId: "l1", reason: "  Caja rota ", notes: "en bodega"))
        #expect(body["locationId"] as? String == "l1")
        #expect(body["reason"] as? String == "Caja rota")
        #expect(body["notes"] as? String == "en bodega")
    }

    @Test("given blank Razón and Notas, should leave them out")
    func blankNotes() throws {
        let body = try json(StockCountEntryRequest(productId: "p1", countedQuantity: 5, unitCost: nil, clientRequestId: "r",
                                                   reason: "  ", notes: ""))
        #expect(body["reason"] == nil)
        #expect(body["notes"] == nil)
    }

    @Test("given Poner en 0, should name the store")
    func zeroBody() throws {
        #expect(try json(StockCountZeroRequest(productIds: ["p1"], locationId: "l1"))["locationId"] as? String == "l1")
    }
}

struct CountLotsLoadTests {
    private let session = StockCountSession(id: "c1", startedAt: .now, countedProducts: 0)

    @Test("given an open count and no lots read yet, should read them, and not show them until then")
    func needsFirstLoad() {
        let load = CountLotsLoad()
        #expect(load.needsLoad(locationId: "l1", session: session))
        #expect(!load.isAvailable(locationId: "l1", session: session))
    }

    @Test("given lots read for this store and count, should not read them again, so edits survive a reload")
    func loadedOnce() {
        var load = CountLotsLoad()
        load.loaded(locationId: "l1", session: session)
        #expect(!load.needsLoad(locationId: "l1", session: session))
        #expect(load.isAvailable(locationId: "l1", session: session))
    }

    @Test("given another store, or another count, should hide the old lots and read them again")
    func otherStoreOrCount() {
        var load = CountLotsLoad()
        load.loaded(locationId: "l1", session: session)
        let other = StockCountSession(id: "c2", startedAt: .now, countedProducts: 0)
        #expect(load.needsLoad(locationId: "l2", session: session))
        #expect(!load.isAvailable(locationId: "l2", session: session))
        #expect(load.needsLoad(locationId: "l1", session: other))
    }

    @Test("given no open count, should neither read nor show lots")
    func noCount() {
        var load = CountLotsLoad()
        load.loaded(locationId: "l1", session: session)
        #expect(!load.needsLoad(locationId: "l1", session: nil))
        #expect(!load.isAvailable(locationId: "l1", session: nil))
    }
}

struct LotSplitPrefilledTests {
    private let jan = MonthYear(year: 2027, month: 1)
    private let mar = MonthYear(year: 2027, month: 3)

    @Test("given several pre-filled lots, should keep their quantities when the count changes")
    func severalKept() {
        var split = LotSplit(prefilled: [CountLot(quantity: 6, expiry: jan), CountLot(quantity: 4, expiry: mar)], stock: 10)
        split.countChanged(from: 10, to: 11)
        #expect(split.rows.map(\.quantity) == [6, 4])
    }

    @Test("given pre-filled lots kept, should give a new lot the rest of the count")
    func newLotGetsRest() {
        var split = LotSplit(prefilled: [CountLot(quantity: 6, expiry: jan), CountLot(quantity: 4, expiry: mar)], stock: 10)
        split.countChanged(from: 10, to: 11)
        split.add(CountLot(), count: 11)
        #expect(split.rows.map(\.quantity) == [6, 4, 1])
    }

    @Test("given one pre-filled lot under the stock (the rest has no lot), should keep it, not label the rest")
    func partialLotKept() {
        var split = LotSplit(prefilled: [CountLot(quantity: 40, expiry: jan)], stock: 65)
        split.countChanged(from: 65, to: 66)
        #expect(split.rows.map(\.quantity) == [40])
    }

    @Test("given one pre-filled lot that is the whole stock, should follow the count")
    func wholeStockFollows() {
        var split = LotSplit(prefilled: [CountLot(quantity: 65, expiry: jan)], stock: 65)
        split.countChanged(from: 65, to: 66)
        #expect(split.rows.map(\.quantity) == [66])
    }
}

struct CountLotIgnoredHintTests {
    private let jan = MonthYear(year: 2027, month: 1)

    @Test("given a lot with a caducidad or lote but no units, should say it won't be saved")
    func hint() {
        #expect(CountLot(quantity: 0, expiry: jan).ignoredHint == "Sin cantidad: este lote no se guardará")
        #expect(CountLot(quantity: nil, batchNumber: "A1").ignoredHint == "Sin cantidad: este lote no se guardará")
    }

    @Test("given a lot with units, or an empty row, should say nothing")
    func noHint() {
        #expect(CountLot(quantity: 3, expiry: jan).ignoredHint == nil)
        #expect(CountLot().ignoredHint == nil)
    }
}

struct CountLotsLimitTests {
    private let jan = MonthYear(year: 2027, month: 1)

    @Test("given more than 50 lots, should block Guardar with the API's limit")
    func overLimit() {
        let rows = (0..<51).map { _ in CountLot(quantity: 1, expiry: jan) }
        #expect(CountLots(rows).check(counted: 51) == .mismatch("Un conteo puede tener como máximo 50 lotes"))
    }

    @Test("given 50 lots, should allow them, and say no more can be added")
    func atLimit() {
        let rows = (0..<50).map { _ in CountLot(quantity: 1, expiry: jan) }
        #expect(CountLots(rows).check(counted: 50) == .matches)
        #expect(!CountLots.canAdd(to: rows))
        #expect(CountLots.canAdd(to: Array(rows.dropLast())))
    }
}

struct CountNotesLimitTests {
    @Test("given Razón or Notas over 500 characters (after trimming), should say so, as the API would refuse it")
    func tooLong() {
        let long = String(repeating: "a", count: 501)
        #expect(CountNotes.problem(reason: long, notes: "") == "La razón y las notas deben tener 500 caracteres o menos")
        #expect(CountNotes.problem(reason: "", notes: long) != nil)
    }

    @Test("given 500 characters, or spaces around a short text, should allow it")
    func withinLimit() {
        #expect(CountNotes.problem(reason: String(repeating: "a", count: 500), notes: "") == nil)
        #expect(CountNotes.problem(reason: "  ok  " + String(repeating: " ", count: 600), notes: "") == nil)
    }
}
