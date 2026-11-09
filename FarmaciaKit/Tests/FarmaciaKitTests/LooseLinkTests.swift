import Foundation
import Testing
@testable import FarmaciaKit

/// PATCH /products/:id/loose-link links a box to this store's suelto. The API
/// only clears the link on an explicit `null`; a missing key leaves it as is.
struct LooseLinkRequestTests {
    private func json(_ request: LooseLinkRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("given an unlink, should encode looseProductId as an explicit null")
    func unlinkSendsNull() throws {
        let body = try json(.unlink)
        #expect(body.keys.contains("looseProductId"))
        #expect(body["looseProductId"] is NSNull)
        #expect(body["quantity"] == nil)
    }

    @Test("given a link with no quantity change, should omit quantity")
    func linkWithoutQuantity() throws {
        let body = try json(LooseLinkRequest(looseProductId: "s1", quantity: nil))
        #expect(body["looseProductId"] as? String == "s1")
        #expect(!body.keys.contains("quantity"))
    }

    @Test("given a typed quantity, should encode it")
    func linkWithQuantity() throws {
        let body = try json(LooseLinkRequest(looseProductId: "s1", quantity: 20))
        #expect(body["quantity"] as? Int == 20)
    }
}

/// The "Vincular caja con suelto" form, with the web's wording (BreakBulkScreen.tsx).
struct LooseLinkFormTests {
    @Test("given no box or no suelto, should fail asking for both",
          arguments: [(nil, "s1"), ("b1", nil), (nil, nil)] as [(String?, String?)])
    func missingProduct(boxId: String?, sueltoId: String?) {
        let check = LooseLinkForm.validate(boxId: boxId, boxQuantity: 20, sueltoId: sueltoId, quantityText: "20")
        #expect(check == .fail("Elige el producto de caja y el producto suelto"))
    }

    @Test("given the same product as box and suelto, should fail before sending")
    func selfLink() {
        let check = LooseLinkForm.validate(boxId: "b1", boxQuantity: 20, sueltoId: "b1", quantityText: "20")
        #expect(check == .fail("Un producto no puede ser su propio producto suelto"))
    }

    @Test("given a box with no quantity and an empty field, should ask for the pieces per box",
          arguments: ["", "  "])
    func missingQuantity(text: String) {
        let check = LooseLinkForm.validate(boxId: "b1", boxQuantity: nil, sueltoId: "s1", quantityText: text)
        #expect(check == .fail("Este producto no tiene cantidad (piezas por caja) — indícala"))
    }

    @Test("given a quantity that isn't a whole number above zero, should fail",
          arguments: ["0", "-3", "abc", "2.5"])
    func badQuantity(text: String) {
        let check = LooseLinkForm.validate(boxId: "b1", boxQuantity: 20, sueltoId: "s1", quantityText: text)
        #expect(check == .fail("La cantidad debe ser un número entero mayor que cero"))
    }

    @Test("given the box's own quantity or an empty field, should not resend quantity",
          arguments: ["20", " 20 ", "20\n", ""])
    func unchangedQuantity(text: String) {
        let check = LooseLinkForm.validate(boxId: "b1", boxQuantity: 20, sueltoId: "s1", quantityText: text)
        #expect(check == .send(LooseLinkRequest(looseProductId: "s1", quantity: nil)))
    }

    @Test("given a new quantity, should send it")
    func newQuantity() {
        let check = LooseLinkForm.validate(boxId: "b1", boxQuantity: nil, sueltoId: "s1", quantityText: "12")
        #expect(check == .send(LooseLinkRequest(looseProductId: "s1", quantity: 12)))
    }

    @Test("given a box with quantity 20, should prefill 20; given none, should prefill nothing")
    func prefill() {
        #expect(LooseLinkForm.prefill(boxQuantity: 20) == "20")
        #expect(LooseLinkForm.prefill(boxQuantity: nil) == "")
    }

    @Test("given a sku, quantity and a link at this store, should read like the web's row hint")
    func subtitleFull() {
        #expect(LooseLinkForm.pickerSubtitle(sku: "123", quantity: 20, linked: true)
                == "SKU 123 · cantidad 20 · ya vinculado")
    }

    @Test("given no sku, quantity or link, should read Sin SKU")
    func subtitleBare() {
        #expect(LooseLinkForm.pickerSubtitle(sku: nil, quantity: nil, linked: false) == "Sin SKU")
    }

    @Test("given a link at Centro, should name both products and the store")
    func linkedText() {
        #expect(LooseLinkForm.linkedText(box: "Caja X", suelto: "Suelto Y", store: "Centro")
                == "\"Caja X\" vinculado con \"Suelto Y\" en Centro.")
    }

    @Test("given an unlink at Centro, should name the box and the store")
    func unlinkedText() {
        #expect(LooseLinkForm.unlinkedText(box: "Caja X", store: "Centro") == "\"Caja X\" desvinculado en Centro.")
    }
}
