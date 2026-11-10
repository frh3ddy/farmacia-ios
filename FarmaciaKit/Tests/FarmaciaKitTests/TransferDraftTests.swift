import Foundation
import Testing
@testable import FarmaciaKit

/// Más → Transferencias: the list of products being sent to another store in one go.
struct TransferDraftAddTests {
    @Test("given an empty draft, adding Aspirina with 12 available should add one line with quantity 1")
    func addsLine() {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.add(productId: "asp", name: "Aspirina", available: 12)
        #expect(draft.lines == [.init(productId: "asp", name: "Aspirina", available: 12, quantity: 1)])
    }

    @Test("given Aspirina already in the list, adding it again should raise its quantity to 2, not add a second line")
    func secondScanRaisesQuantity() {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.add(productId: "asp", name: "Aspirina", available: 12)
        draft.add(productId: "asp", name: "Aspirina", available: 12)
        #expect(draft.lines.map(\.quantity) == [2])
    }

    @Test("given a product whose stock here is unknown, should count it as none, so it can't be sent")
    func unknownStock() {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.add(productId: "asp", name: "Aspirina", available: nil)
        #expect(draft.lines.first?.available == 0)
        #expect(!draft.canSend(destinationId: "oriente"))
    }

    @Test("given two lines, removing one should drop only it")
    func removesLine() {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.add(productId: "asp", name: "Aspirina", available: 12)
        draft.add(productId: "ibu", name: "Ibuprofeno", available: 3)
        draft.remove(productId: "asp")
        #expect(draft.lines.map(\.productId) == ["ibu"])
    }

    @Test("given a line, setting its quantity should change only that line")
    func setsQuantity() {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.add(productId: "asp", name: "Aspirina", available: 12)
        draft.add(productId: "ibu", name: "Ibuprofeno", available: 3)
        draft.setQuantity(5, for: "asp")
        #expect(draft.lines.map(\.quantity) == [5, 1])
    }
}

struct TransferDraftLineIssueTests {
    @Test("given quantity 0, should ask for more than zero")
    func zero() {
        #expect(TransferDraft.lineIssue(quantity: 0, available: 12) == "La cantidad debe ser mayor que cero")
    }

    @Test("given 15 with 12 available, should say only 12 are here")
    func moreThanOnHand() {
        #expect(TransferDraft.lineIssue(quantity: 15, available: 12) == "Solo hay 12 en esta tienda")
    }

    @Test("given 0 available, should say there's no stock here")
    func noneOnHand() {
        #expect(TransferDraft.lineIssue(quantity: 1, available: 0) == "Sin existencias en esta tienda")
    }

    @Test("given 5 with 12 available, should have no issue", arguments: [1, 5, 12])
    func fine(quantity: Int) {
        #expect(TransferDraft.lineIssue(quantity: quantity, available: 12) == nil)
    }
}

struct TransferDraftCanSendTests {
    private func draft(_ lines: [(String, Int, Int)]) -> TransferDraft {
        var draft = TransferDraft(clientRequestId: "r1")
        for (id, available, quantity) in lines {
            draft.add(productId: id, name: id, available: available)
            draft.setQuantity(quantity, for: id)
        }
        return draft
    }

    @Test("given no destination, should not send")
    func noDestination() {
        #expect(!draft([("asp", 12, 2)]).canSend(destinationId: nil))
    }

    @Test("given a destination and no lines, should not send")
    func noLines() {
        #expect(!draft([]).canSend(destinationId: "oriente"))
    }

    @Test("given a line with an issue, should not send")
    func lineWithIssue() {
        #expect(!draft([("asp", 12, 2), ("ibu", 3, 4)]).canSend(destinationId: "oriente"))
    }

    @Test("given 101 lines, should not send and say the cap is 100")
    func overCap() {
        let many = draft((0...100).map { ("p\($0)", 5, 1) })
        #expect(!many.canSend(destinationId: "oriente"))
        #expect(many.capIssue == "Máximo 100 productos por envío")
        #expect(draft((1...100).map { ("p\($0)", 5, 1) }).capIssue == nil)
    }

    @Test("given what's missing, should say what to fix before sending")
    func sendIssueText() {
        #expect(draft([("asp", 12, 2)]).sendIssue(destinationId: nil) == "Elige la sucursal destino")
        #expect(draft([]).sendIssue(destinationId: "oriente") == "Agrega al menos un producto")
        #expect(draft([("asp", 12, 20)]).sendIssue(destinationId: "oriente") == "Revisa las cantidades marcadas")
        #expect(draft([("asp", 12, 2)]).sendIssue(destinationId: "oriente") == nil)
    }

    @Test("given a destination and valid lines, should send")
    func valid() {
        #expect(draft([("asp", 12, 2), ("ibu", 3, 3)]).canSend(destinationId: "oriente"))
    }
}

struct TransferDraftDestinationTests {
    @Test("given Centro and Oriente with the session at Centro, should offer only Oriente")
    func excludesCurrent() {
        #expect(TransferDraft.destinations(all: ["centro", "oriente"], current: "centro") == ["oriente"])
    }

    @Test("given exactly one other store, should pick it by default")
    func onlyOtherIsDefault() {
        #expect(TransferDraft.defaultDestination(all: ["centro", "oriente"], current: "centro") == "oriente")
    }

    @Test("given Oriente inactive, should offer no store and pick none")
    func inactiveExcluded() {
        #expect(TransferDraft.destinations(all: ["centro", "oriente"], inactive: ["oriente"], current: "centro").isEmpty)
        #expect(TransferDraft.defaultDestination(all: ["centro", "oriente"], inactive: ["oriente"], current: "centro") == nil)
    }

    @Test("given two other stores, should make the user pick")
    func severalNoDefault() {
        #expect(TransferDraft.defaultDestination(all: ["centro", "oriente", "norte"], current: "centro") == nil)
    }
}

struct TransferDraftSummaryTests {
    @Test("given 3 lines with 24 pieces, should read 3 productos · 24 unidades")
    func plural() {
        var draft = TransferDraft(clientRequestId: "r1")
        for (id, quantity) in [("a", 10), ("b", 10), ("c", 4)] {
            draft.add(productId: id, name: id, available: 50)
            draft.setQuantity(quantity, for: id)
        }
        #expect(draft.summary == "3 productos · 24 unidades")
    }

    @Test("given 1 line with 1 piece, should read 1 producto · 1 unidad")
    func singular() {
        var draft = TransferDraft(clientRequestId: "r1")
        draft.add(productId: "a", name: "a", available: 5)
        #expect(draft.summary == "1 producto · 1 unidad")
    }
}

struct TransferTextTests {
    @Test("given a product with SKU 750 and 12 here, should read its SKU and what's here")
    func pickerSubtitle() {
        #expect(TransferDraft.pickerSubtitle(sku: "750", available: 12) == "SKU 750 · hay 12 aquí")
    }

    @Test("given no SKU and unknown stock, should read Sin existencias aquí")
    func pickerSubtitleUnknown() {
        #expect(TransferDraft.pickerSubtitle(sku: nil, available: nil) == "Sin existencias aquí")
        #expect(TransferDraft.pickerSubtitle(sku: "", available: 0) == "Sin existencias aquí")
    }

    @Test("given a shipment received on send, should say it was sent and is already there")
    func sentReceived() {
        #expect(TransferDraft.sentText(destination: "Oriente", inTransit: false, products: 3, pieces: 24)
            == "Enviado a Oriente: 3 productos · 24 unidades. Ya están en su inventario.")
    }

    @Test("given a shipment in transit, should say the destination confirms it")
    func sentInTransit() {
        #expect(TransferDraft.sentText(destination: "Oriente", inTransit: true, products: 1, pieces: 1)
            == "En camino a Oriente: 1 producto · 1 unidad. Oriente lo confirmará al recibir.")
    }

    @Test("given a transfer whose Square update failed, should name the product and the fix")
    func squareFailed() {
        #expect(TransferError.squareFailed(product: "Aspirina")
            == "Aspirina: Square no se actualizó. El dueño puede reintentarlo en la web.")
    }

    @Test("given a shipment out of this store, should read Para the destination; into it, De the origin")
    func direction() {
        #expect(TransferDraft.direction(from: "Centro", to: "Oriente", outgoing: true) == "Para Oriente")
        #expect(TransferDraft.direction(from: "Centro", to: "Oriente", outgoing: false) == "De Centro")
    }
}

struct ReceiveOnSendChoiceTests {
    @Test("given Confirmar al llegar off and access allowed, should receive on send")
    func receivesOnSend() {
        #expect(TransferDraft.receivesOnSend(confirmOnArrival: false, allowed: true))
    }

    @Test("given Confirmar al llegar on, or no access to the destination, should leave it in transit",
          arguments: [(true, true), (false, false), (true, false)])
    func staysInTransit(confirm: Bool, allowed: Bool) {
        #expect(!TransferDraft.receivesOnSend(confirmOnArrival: confirm, allowed: allowed))
    }
}

/// Transferencias' two lists, from GET /transfers/shipments (either side of this store).
struct ShipmentListTests {
    @Test("given a shipment in transit to this store, should be in Por recibir and not in Recientes")
    func inTransitHere() {
        #expect(ShipmentList.isToReceive(inTransit: true, toLocationId: "oriente", current: "oriente"))
    }

    @Test("given one in transit from this store, or one already received, should be in Recientes",
          arguments: [(true, "centro"), (false, "oriente")])
    func recent(inTransit: Bool, to: String) {
        #expect(!ShipmentList.isToReceive(inTransit: inTransit, toLocationId: to, current: "oriente"))
    }

    @Test("given 12 recent shipments, should show the newest 10")
    func recentLimit() {
        #expect(ShipmentList.recent(Array(1...12)) == Array(1...10))
    }
}

struct SendUncertainTests {
    @Test("given a timeout or lost connection, should say it may have gone through")
    func uncertain() {
        for error in [NetworkError.timeout, .networkUnavailable, .unknown(URLError(.badServerResponse))] {
            #expect(TransferError.mayHaveSent(error), "\(error)")
        }
    }

    @Test("given a refusal or a server answer, should not")
    func certain() {
        let refusal = NetworkError.Refusal(code: "INSUFFICIENT_STOCK", message: "x", productId: nil, available: nil)
        for error in [NetworkError.refused(refusal), .httpError(statusCode: 400, message: "x"), .unauthorized] {
            #expect(!TransferError.mayHaveSent(error), "\(error)")
        }
    }

    @Test("given an uncertain send, should tell them to check Recientes before changing the list")
    func text() {
        #expect(TransferError.mayHaveSentText
            == "Puede que ya se haya enviado. Revisa Recientes antes de cambiar la lista; reenviarla tal cual no la duplica.")
    }
}
