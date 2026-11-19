import Foundation
import Testing
@testable import FarmaciaKit

struct ReceivingCostFixTests {
    @Test("given a manager, should not offer Corregir costo; given the owner, should", arguments: [(false, false), (true, true)])
    func ownerOnly(isOwner: Bool, offered: Bool) {
        #expect(ReceivingCostFix.canFix(isOwner: isOwner) == offered)
    }

    @Test("given \"26.71\", \"26,71\", \" 0 \", should read the exact cost",
          arguments: [("26.71", "26.71"), ("26,71", "26.71"), (" 0 ", "0")])
    func readsCost(text: String, expected: String) {
        #expect(ReceivingCostFix.cost(from: text) == Decimal(string: expected))
    }

    @Test("given empty, negative, or non-numeric text, should read no cost",
          arguments: ["", "-1", "abc", "26.7.1", "$26"])
    func rejectsCost(text: String) {
        #expect(ReceivingCostFix.cost(from: text) == nil)
    }

    @Test("given a new cost that differs from the receiving's, should allow saving; the same cost or none, should not")
    func canSave() {
        #expect(ReceivingCostFix.canSave(newCost: Decimal(string: "26.71"), oldCost: "30.0000"))
        #expect(ReceivingCostFix.canSave(newCost: 0, oldCost: "30"))
        #expect(!ReceivingCostFix.canSave(newCost: 30, oldCost: "30.0000"))
        #expect(!ReceivingCostFix.canSave(newCost: nil, oldCost: "30"))
    }

    @Test("given 26.71, should send {\"unitCost\":26.71} exactly, not a binary-float approximation")
    func body() throws {
        let data = try JSONEncoder().encode(ReceivingCostFix.Request(unitCost: Decimal(string: "26.71")!))
        #expect(String(decoding: data, as: UTF8.self) == #"{"unitCost":26.71}"#)
    }

    @Test("given old 30 and new 26.71, should show both side by side")
    func comparison() {
        #expect(ReceivingCostFix.comparison(oldCost: "30.0000", newCost: Decimal(string: "26.71")!) == "$30.00 → $26.71")
    }

    @Test("given a 409 refusal, should show the API's message as-is")
    func conflictMessage() throws {
        let message = "No se puede corregir el costo: ya se transfirieron unidades de esta recepción"
        let body = try JSONSerialization.data(withJSONObject: ["statusCode": 409, "message": message])
        let error = try #require(NetworkError.from(statusCode: 409, body: body))
        #expect(SaveOutcome(error: error, fallback: ReceivingCostFix.failure) == .failed(message))
    }

    @Test("given a dropped connection, should fail rather than queue: a late replay could recost after other changes")
    func notQueuedOffline() {
        #expect(!OfflineReplay.isReplaySafe(method: "POST", path: "/inventory/receive/r1/cost"))
    }
}
