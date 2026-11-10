import Foundation
import Testing
@testable import FarmaciaKit

/// POST /transfers/batch, POST /transfers/shipments/:id/receive, and the text around them.
struct TransferBatchRequestTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func twoLines(id: String = "r1") -> TransferDraft {
        var draft = TransferDraft(clientRequestId: id)
        draft.add(productId: "asp", name: "Aspirina", available: 12)
        draft.add(productId: "ibu", name: "Ibuprofeno", available: 3)
        draft.setQuantity(4, for: "asp")
        return draft
    }

    @Test("given two lines, should encode toLocationId, receiveOnSend and items with productId and quantity")
    func encodesBatch() throws {
        let body = try json(twoLines().request(destinationId: "oriente", receiveOnSend: true))
        #expect(body["toLocationId"] as? String == "oriente")
        #expect(body["receiveOnSend"] as? Bool == true)
        #expect(body["clientRequestId"] as? String == "r1")
        let items = try #require(body["items"] as? [[String: Any]])
        #expect(items.map { $0["productId"] as? String } == ["asp", "ibu"])
        #expect(items.map { $0["quantity"] as? Int } == [4, 1])
    }

    @Test("given the same draft encoded twice, should keep the same clientRequestId")
    func retryKeepsId() {
        let draft = twoLines()
        #expect(draft.request(destinationId: "o", receiveOnSend: false).clientRequestId
            == draft.request(destinationId: "o", receiveOnSend: false).clientRequestId)
    }

    @Test("given its request id was used by another store, renewing should keep the list with a new id")
    func renewKeepsLines() {
        var draft = twoLines(id: "r1")
        draft.renewRequestId("r2")
        #expect(draft.clientRequestId == "r2")
        #expect(draft.lines.map(\.productId) == ["asp", "ibu"])
    }

    @Test("after a send succeeds and the draft is reset, should be empty with a new clientRequestId")
    func resetGetsNewId() {
        var draft = twoLines(id: "r1")
        draft.reset(clientRequestId: "r2")
        #expect(draft.lines.isEmpty)
        #expect(draft.clientRequestId == "r2")
    }
}

struct TransferErrorTests {
    @Test("given INSUFFICIENT_STOCK for Aspirina with 4 available, should name the product and what's here")
    func insufficient() {
        #expect(TransferError.message(code: "INSUFFICIENT_STOCK", productName: "Aspirina", available: 4,
                                      destination: "Oriente", fallback: "x") == "Aspirina: solo hay 4 en esta tienda")
    }

    @Test("given INSUFFICIENT_STOCK without the amount, should still name the product")
    func insufficientWithoutAmount() {
        #expect(TransferError.message(code: "INSUFFICIENT_STOCK", productName: "Aspirina", available: nil,
                                      destination: "Oriente", fallback: "x") == "Aspirina: no hay suficientes en esta tienda")
    }

    @Test("given PRODUCT_NOT_SOLD_AT_LOCATION, should say the product isn't sold at the destination")
    func notSold() {
        #expect(TransferError.message(code: "PRODUCT_NOT_SOLD_AT_LOCATION", productName: "Aspirina", available: nil,
                                      destination: "Oriente", fallback: "x") == "Aspirina no se vende en Oriente")
    }

    @Test("given DESTINATION_NOT_CUT_OVER, should say the destination hasn't done its opening count")
    func notCutOver() {
        #expect(TransferError.message(code: "DESTINATION_NOT_CUT_OVER", productName: nil, available: nil,
                                      destination: "Oriente", fallback: "x") == "Oriente aún no ha hecho su conteo inicial")
    }

    @Test("given LOCATION_NOT_CUT_OVER, should say this store hasn't done its opening count")
    func originNotCutOver() {
        #expect(TransferError.message(code: "LOCATION_NOT_CUT_OVER", productName: "Aspirina", available: nil,
                                      destination: "Oriente", fallback: "x") == "Esta tienda aún no ha hecho su conteo inicial")
    }

    @Test("given RECEIVE_ON_SEND_NOT_ALLOWED, should tell them to send with Confirmar al llegar")
    func receiveOnSendRefused() {
        #expect(TransferError.message(code: "RECEIVE_ON_SEND_NOT_ALLOWED", productName: nil, available: nil,
                                      destination: "Oriente", fallback: "x")
            == "No tienes acceso a Oriente: envía con «Confirmar al llegar»")
    }

    @Test("given CLIENT_REQUEST_ID_REUSED, should ask to send again (the list gets a new id)")
    func requestIdReused() {
        #expect(TransferError.message(code: "CLIENT_REQUEST_ID_REUSED", productName: nil, available: nil,
                                      destination: "Oriente", fallback: "x") == "No se pudo enviar. Toca Enviar de nuevo.")
        #expect(TransferError.needsNewRequestId(code: "CLIENT_REQUEST_ID_REUSED"))
        #expect(!TransferError.needsNewRequestId(code: "INSUFFICIENT_STOCK"))
    }

    @Test("given an unknown or missing code, should show the server's message", arguments: [nil, "SOMETHING_NEW"])
    func unknown(code: String?) {
        #expect(TransferError.message(code: code, productName: "Aspirina", available: nil,
                                      destination: "Oriente", fallback: "Error del servidor") == "Error del servidor")
    }
}

struct ShipmentReceiptTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func overrides(_ receipt: ShipmentReceipt) throws -> [String: Int] {
        let lines = try json(receipt.request)["lines"] as? [[String: Any]] ?? []
        return Dictionary(uniqueKeysWithValues: lines.map { ($0["transferLineId"] as! String, $0["quantityReceived"] as! Int) })
    }

    /// Aspirina went out as two lots (6 + 4); Ibuprofeno as one lot of 5.
    private let shipment = ShipmentReceipt(transfers: [
        .init(id: "asp", lines: [.init(id: "a1", quantity: 6), .init(id: "a2", quantity: 4)]),
        .init(id: "ibu", lines: [.init(id: "i1", quantity: 5)]),
    ])

    @Test("given nothing edited, should send no lines: everything arrives as sent")
    func untouchedSendsNothing() throws {
        #expect(try json(shipment.request).isEmpty)
        #expect(shipment.sent(for: "asp") == 10)
    }

    @Test("given a product edited back to its sent 10, should still send no override")
    func editedBackSendsNothing() throws {
        var receipt = shipment
        receipt.received["asp"] = 10
        #expect(try json(receipt.request).isEmpty)
    }

    @Test("given 8 of 10 Aspirina received, should take the 2 missing from the last lot and read Faltan 2")
    func shortFromLastLot() throws {
        var receipt = shipment
        receipt.received["asp"] = 8
        #expect(try overrides(receipt) == ["a2": 2])
        #expect(receipt.note(for: "asp") == "Faltan 2")
        #expect(receipt.note(for: "ibu") == nil)
    }

    @Test("given 3 of 10 received, should empty the last lot and take the rest from the one before")
    func shortAcrossLots() throws {
        var receipt = shipment
        receipt.received["asp"] = 3
        #expect(try overrides(receipt) == ["a1": 3, "a2": 0])
    }

    @Test("given none of 10 received, should send zero for every lot")
    func noneArrived() throws {
        var receipt = shipment
        receipt.received["asp"] = 0
        #expect(try overrides(receipt) == ["a1": 0, "a2": 0])
        #expect(receipt.canReceive)
    }

    @Test("given more received than was sent, or a negative, should be an issue and block Recibir")
    func overReceived() {
        var receipt = shipment
        receipt.received["asp"] = 11
        #expect(receipt.note(for: "asp") == "No puede ser más de 10")
        #expect(!receipt.canReceive)
        receipt.received["asp"] = -1
        #expect(receipt.note(for: "asp") == "La cantidad no puede ser negativa")
        #expect(!receipt.canReceive)
    }
}

struct ReceiveOnSendAccessTests {
    @Test("given a manager without access to Oriente, should not allow receive on send")
    func managerWithoutAccess() {
        #expect(!TransferDraft.receiveOnSendAllowed(isOwner: false, accessibleStoreIds: ["centro"], destinationId: "oriente"))
    }

    @Test("given a manager with access to both stores, should allow it")
    func managerAtBoth() {
        #expect(TransferDraft.receiveOnSendAllowed(isOwner: false, accessibleStoreIds: ["centro", "oriente"], destinationId: "oriente"))
    }

    @Test("given the owner, should allow it")
    func owner() {
        #expect(TransferDraft.receiveOnSendAllowed(isOwner: true, accessibleStoreIds: [], destinationId: "oriente"))
    }
}

struct TransferStatusTests {
    @Test("given each status, should read its Spanish title",
          arguments: [("IN_TRANSIT", "En tránsito"), ("RECEIVED", "Recibida"), ("CANCELLED", "Cancelada"), ("PENDING", "Pendiente")])
    func titles(raw: String, title: String) throws {
        #expect(try #require(TransferStatus(rawValue: raw)).title == title)
        #expect(TransferStatus.title(raw: raw) == title)
    }

    @Test("given a status this app doesn't know yet, should show it as sent instead of failing")
    func unknownStatus() {
        #expect(TransferStatus.title(raw: "PARTIAL") == "PARTIAL")
    }
}
