import Foundation
import Testing
@testable import FarmaciaKit

/// Pausar / Reanudar on the product detail (POST and DELETE /products/:id/pause, stock alerts O5).
struct PauseFormTests {
    private func json(_ request: PauseRequest) throws -> [String: String] {
        let data = try JSONEncoder().encode(request)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    @Test("given Proveedor sin surtido and no note, should send the store and the reason only")
    func reasonOnly() throws {
        let check = PauseForm.validate(productId: "p1", locationId: "loc", reason: .supplierUnavailable, replacementId: nil, note: "  ")
        guard case .send(let request) = check else { Issue.record("expected send, got \(check)"); return }
        #expect(try json(request) == ["locationId": "loc", "reason": "SUPPLIER_UNAVAILABLE"])
    }

    @Test("given a note with spaces around it, should send it trimmed")
    func trimsNote() throws {
        let check = PauseForm.validate(productId: "p1", locationId: "loc", reason: .other, replacementId: nil, note: " Temporada \n")
        guard case .send(let request) = check else { Issue.record("expected send, got \(check)"); return }
        #expect(request.note == "Temporada")
    }

    @Test("given no reason chosen, should ask for one")
    func noReason() {
        #expect(PauseForm.validate(productId: "p1", locationId: "loc", reason: nil, replacementId: nil, note: "") == .fail("Elige un motivo"))
    }

    @Test("given Reemplazado por equivalente, should send the replacement; without one, ask for it")
    func replacement() throws {
        let check = PauseForm.validate(productId: "p1", locationId: "loc", reason: .replacedByEquivalent, replacementId: "p2", note: "")
        guard case .send(let request) = check else { Issue.record("expected send, got \(check)"); return }
        #expect(try json(request) == ["locationId": "loc", "reason": "REPLACED_BY_EQUIVALENT", "replacedByProductId": "p2"])
        #expect(PauseForm.validate(productId: "p1", locationId: "loc", reason: .replacedByEquivalent, replacementId: nil, note: "")
                == .fail("Elige el producto que lo reemplaza"))
    }

    @Test("given the product itself as its replacement, should refuse it")
    func replacedBySelf() {
        #expect(PauseForm.validate(productId: "p1", locationId: "loc", reason: .replacedByEquivalent, replacementId: "p1", note: "")
                == .fail("Un producto no puede reemplazarse a sí mismo"))
    }

    @Test("given a replacement picked and then another reason, should not send the replacement (the API refuses it)")
    func replacementOnlyWithEquivalent() throws {
        let check = PauseForm.validate(productId: "p1", locationId: "loc", reason: .slowMover, replacementId: "p2", note: "")
        guard case .send(let request) = check else { Issue.record("expected send, got \(check)"); return }
        #expect(request.replacedByProductId == nil)
    }

    @Test("given a note over 500 characters, should refuse it like the API")
    func longNote() {
        let note = String(repeating: "a", count: 501)
        #expect(PauseForm.validate(productId: "p1", locationId: "loc", reason: .other, replacementId: nil, note: note)
                == .fail("La nota debe tener hasta 500 caracteres"))
    }
}

struct PauseActionTests {
    private let paused = StockAlert(level: .none, paused: true, pauseReason: .slowMover)
    private let active = StockAlert(level: .out)

    @Test("given a manager and a product that isn't paused, should offer Pausar; paused, Reanudar")
    func pauseOrResume() {
        #expect(PauseForm.action(alert: active, isManager: true, tracksInventory: true, soldOnlyAtLocationId: nil, currentLocationId: "loc") == .pause)
        #expect(PauseForm.action(alert: paused, isManager: true, tracksInventory: true, soldOnlyAtLocationId: nil, currentLocationId: "loc") == .resume)
    }

    @Test("given a cashier, should offer nothing (the API is owner/manager only)")
    func cashier() {
        #expect(PauseForm.action(alert: active, isManager: false, tracksInventory: true, soldOnlyAtLocationId: nil, currentLocationId: "loc") == nil)
    }

    @Test("given an old server (no alert), a Yastás service, or a product sold only at another store, should offer nothing")
    func notPausable() {
        #expect(PauseForm.action(alert: nil, isManager: true, tracksInventory: true, soldOnlyAtLocationId: nil, currentLocationId: "loc") == nil)
        #expect(PauseForm.action(alert: active, isManager: true, tracksInventory: false, soldOnlyAtLocationId: nil, currentLocationId: "loc") == nil)
        #expect(PauseForm.action(alert: active, isManager: true, tracksInventory: true, soldOnlyAtLocationId: "other", currentLocationId: "loc") == nil)
    }

    @Test("given a paused product sold only at another store, should still offer Reanudar")
    func resumeAnywhere() {
        #expect(PauseForm.action(alert: paused, isManager: true, tracksInventory: true, soldOnlyAtLocationId: "other", currentLocationId: "loc") == .resume)
    }
}

/// The line under the stock number on the product detail.
struct StockDetailTextTests {
    @Test("given a paused product, should show Pausado with its reason instead of Agotado")
    func paused() {
        let alert = StockAlert(level: .none, paused: true, pauseReason: .supplierUnavailable)
        #expect(StockLevel(quantity: 0, alert: alert).detailText == "Pausado · Proveedor sin surtido")
    }

    @Test("given 0 on hand, should say Agotado en esta tienda, alerting or not; given stock, nothing")
    func others() {
        #expect(StockLevel(quantity: 0, alert: StockAlert(level: .out)).detailText == "Agotado en esta tienda")
        #expect(StockLevel(quantity: 0, alert: StockAlert(level: .none)).detailText == "Agotado en esta tienda")
        #expect(StockLevel(quantity: 3, alert: StockAlert(level: .low)).detailText == nil)
        #expect(StockLevel(quantity: 30, alert: nil).detailText == nil)
    }
}
