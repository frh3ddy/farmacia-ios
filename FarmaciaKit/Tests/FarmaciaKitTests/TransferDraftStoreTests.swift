import Foundation
import Testing
@testable import FarmaciaKit

/// The Transferencias list saved on the phone, one per employee and store
/// (tasks/transfer-list-persist-epic.md).
struct TransferDraftStoreTests {
    private func twoLines(id: String = "r1") -> TransferDraft {
        var draft = TransferDraft(clientRequestId: id)
        draft.set(productId: "asp", name: "Aspirina", available: 12, quantity: 4, imageUrl: "https://img/asp")
        draft.set(productId: "ibu", name: "Ibuprofeno", available: 3, quantity: 1)
        return draft
    }

    @Test("given a draft with two lines and request id r1, should decode to an equal draft with the same id")
    func roundTrips() throws {
        let data = try JSONEncoder().encode(twoLines())
        let decoded = try JSONDecoder().decode(TransferDraft.self, from: data)
        #expect(decoded == twoLines())
        #expect(decoded.clientRequestId == "r1")
    }

    @Test("given saved data without the may-have-sent fields (an older or newer app), should load the lines")
    func decodesWithoutFlags() throws {
        let json = #"{"clientRequestId":"r1","lines":[{"productId":"asp","name":"Aspirina","available":12,"quantity":4}]}"#
        let draft = try JSONDecoder().decode(TransferDraft.self, from: Data(json.utf8))
        #expect(draft.lines.map(\.productId) == ["asp"])
        #expect(draft.clientRequestId == "r1")
        #expect(draft.sendWarning == nil)
    }

    @Test("given the same employee at two stores, or two employees at one store, should return different keys")
    func keysPerEmployeeAndStore() {
        let key = TransferDraftStore.key(employeeId: "e1", locationId: "centro")
        #expect(key != nil)
        #expect(key != TransferDraftStore.key(employeeId: "e1", locationId: "oriente"))
        #expect(key != TransferDraftStore.key(employeeId: "e2", locationId: "centro"))
    }

    @Test("given no employee or no store (logout clears the store first), should return no key",
          arguments: [(nil as String?, "centro" as String?), ("e1", nil), (nil, nil)])
    func noKeyWithoutIds(employeeId: String?, locationId: String?) {
        #expect(TransferDraftStore.key(employeeId: employeeId, locationId: locationId) == nil)
    }

    private func defaults() throws -> UserDefaults {
        let name = "TransferDraftStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("given a saved draft, should load it back")
    func savesAndLoads() throws {
        let defaults = try defaults()
        TransferDraftStore.save(twoLines(), to: defaults, key: "k")
        #expect(try TransferDraftStore.load(defaults, key: "k") == twoLines())
    }

    @Test("given nothing saved, should load an empty draft")
    func loadsEmpty() throws {
        #expect(try TransferDraftStore.load(try defaults(), key: "k").lines.isEmpty)
    }

    @Test("given unreadable data, should throw so the screen can say the list was lost")
    func throwsOnBadData() throws {
        let defaults = try defaults()
        defaults.set(Data("nope".utf8), forKey: "k")
        #expect(throws: (any Error).self) { try TransferDraftStore.load(defaults, key: "k") }
    }

    @Test("given a send that finished after a store switch, updating the sent store's list should change only it")
    func updatesAnotherStoresList() throws {
        let defaults = try defaults()
        TransferDraftStore.save(twoLines(id: "a"), to: defaults, key: "A")
        TransferDraftStore.save(twoLines(id: "b"), to: defaults, key: "B")
        TransferDraftStore.update(defaults, key: "A") { $0.reset() }
        #expect(defaults.data(forKey: "A") == nil)
        #expect(try TransferDraftStore.load(defaults, key: "B").clientRequestId == "b")
    }

    @Test("given unreadable data, updating should leave it alone")
    func updateSkipsBadData() throws {
        let defaults = try defaults()
        defaults.set(Data("nope".utf8), forKey: "A")
        TransferDraftStore.update(defaults, key: "A") { $0.markMayHaveSent() }
        #expect(defaults.data(forKey: "A") == Data("nope".utf8))
    }

    @Test("given an empty draft (sent or cleared), should remove the saved one")
    func emptyRemoves() throws {
        let defaults = try defaults()
        TransferDraftStore.save(twoLines(), to: defaults, key: "k")
        TransferDraftStore.save(TransferDraft(), to: defaults, key: "k")
        #expect(defaults.data(forKey: "k") == nil)
    }
}

/// The stock saved with each line goes stale: refreshed when the list loads, and
/// the user is told what changed.
struct TransferStockRefreshTests {
    private func twoLines() -> TransferDraft {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.set(productId: "ibu", name: "Ibuprofeno", available: 3, quantity: 1)
        draft.set(productId: "par", name: "Paracetamol", available: 10, quantity: 4)
        return draft
    }

    @Test("given lines at 10 and 3 and fresh stock 4 and 3, should set 4 and 3 and report only 10 → 4")
    func reportsChanges() {
        var draft = twoLines()
        let changes = draft.refreshAvailable(["par": 4, "ibu": 3])
        #expect(draft.lines.map(\.available) == [4, 3])
        #expect(changes == [TransferStockChange(name: "Paracetamol", before: 10, after: 4)])
    }

    @Test("given a product missing from the fresh stock, should keep its number and report nothing")
    func keepsMissing() {
        var draft = twoLines()
        #expect(draft.refreshAvailable(["par": 10]).isEmpty)
        #expect(draft.lines.map(\.available) == [10, 3])
    }

    @Test("given a refresh, should keep the lines' order, quantities and request id")
    func keepsTheRest() {
        var draft = twoLines()
        draft.refreshAvailable(["par": 0, "ibu": 7])
        #expect(draft.lines.map(\.productId) == ["par", "ibu"])
        #expect(draft.lines.map(\.quantity) == [4, 1])
        #expect(draft.clientRequestId == "r1")
    }

    @Test("given one change, should read it")
    func noticeOne() {
        #expect(TransferStockChange.notice([.init(name: "Paracetamol", before: 10, after: 4)])
                == "Cambiaron las existencias: Paracetamol 10 → 4")
    }

    @Test("given five changes, should list three and count the rest")
    func noticeMany() {
        let changes = (1...5).map { TransferStockChange(name: "P\($0)", before: $0, after: 0) }
        #expect(TransferStockChange.notice(changes)
                == "Cambiaron las existencias: P1 1 → 0, P2 2 → 0, P3 3 → 0 y 2 más")
    }

    @Test("given two lines, should ask POST /transfers/stock for both ids at this store")
    func stockRequest() {
        #expect(twoLines().stockRequest(locationId: "centro")
                == TransferStockRequest(locationId: "centro", productIds: ["par", "ibu"]))
    }

    @Test("given a stock request, should encode the keys POST /transfers/stock reads: locationId and productIds")
    func encodesStockRequest() throws {
        let data = try JSONEncoder().encode(TransferStockRequest(locationId: "centro", productIds: ["par"]))
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(body.keys) == ["locationId", "productIds"])
        #expect(body["locationId"] as? String == "centro")
        #expect(body["productIds"] as? [String] == ["par"])
    }

    @Test("given no lines, should not ask")
    func noStockRequest() {
        #expect(TransferDraft().stockRequest(locationId: "centro") == nil)
    }

    @Test("given more than 100 lines (the server's cap), should ask for the first 100")
    func stockRequestCapped() {
        var draft = TransferDraft()
        for n in 1...101 { draft.set(productId: "p\(n)", name: "P\(n)", available: 1, quantity: 1) }
        #expect(draft.stockRequest(locationId: "centro")?.productIds.count == 100)
    }

    @Test("given a stock refresh in progress, Enviar should wait for it")
    func waitsForRefresh() {
        #expect(twoLines().sendIssue(destinationId: "oriente", refreshingStock: true) == "Actualizando existencias…")
        #expect(twoLines().sendIssue(destinationId: "oriente", refreshingStock: false) == nil)
    }

    @Test("given no changes, should have no notice")
    func noticeNone() {
        #expect(TransferStockChange.notice([]) == nil)
    }
}

/// Enviar timed out: it may have gone through. Resending the same list is safe (same
/// request id); a changed list goes as a new shipment, so the user is warned.
struct TransferMayHaveSentTests {
    private let warning = "Puede que el envío anterior sí haya llegado. Si llegó, este se enviará además. Revisa Recientes."

    private func sentDraft() -> TransferDraft {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.set(productId: "par", name: "Paracetamol", available: 10, quantity: 4)
        draft.markMayHaveSent()
        return draft
    }

    @Test("given a draft marked may-have-sent and then a quantity change, should warn")
    func warnsAfterEdit() {
        var draft = sentDraft()
        draft.setQuantity(5, for: "par")
        #expect(draft.sendWarning == warning)
    }

    @Test("given a product added or removed after may-have-sent, should warn")
    func warnsAfterAddOrRemove() {
        var added = sentDraft()
        added.set(productId: "ibu", name: "Ibuprofeno", available: 3, quantity: 1)
        #expect(added.sendWarning == warning)
        var removed = sentDraft()
        removed.remove(productId: "par")
        #expect(removed.sendWarning == warning)
    }

    @Test("given marked but unedited (a resend replays safely), should not warn")
    func noWarningUnedited() {
        #expect(sentDraft().sendWarning == nil)
    }

    @Test("given a stock refresh after may-have-sent, should not warn (the request is the same)")
    func refreshIsNotAnEdit() {
        var draft = sentDraft()
        draft.refreshAvailable(["par": 2])
        #expect(draft.sendWarning == nil)
    }

    @Test("given an edit and then a renewed request id, should keep warning")
    func renewKeepsWarning() {
        var draft = sentDraft()
        draft.setQuantity(5, for: "par")
        draft.renewRequestId("r2")
        #expect(draft.sendWarning == warning)
    }

    @Test("given a sent or cleared list, should not warn")
    func resetClears() {
        var draft = sentDraft()
        draft.setQuantity(5, for: "par")
        draft.reset()
        #expect(draft.sendWarning == nil)
    }

    @Test("given an edited may-have-sent draft saved and loaded, should still warn")
    func survivesRestart() throws {
        var draft = sentDraft()
        draft.setQuantity(5, for: "par")
        let loaded = try JSONDecoder().decode(TransferDraft.self, from: JSONEncoder().encode(draft))
        #expect(loaded.sendWarning == warning)
    }
}
