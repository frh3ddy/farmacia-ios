import Foundation
import Testing
@testable import FarmaciaKit

/// Shelf age in words (units, not lots) — replaces "inmovilizado" and a bar whose denominator is 2 units.
struct AgingSentenceTests {
    func lot(_ quantity: Int, age: Int) -> BatchValuation {
        BatchValuation(batchId: UUID().uuidString, quantity: quantity, receivedAt: Date(), age: age)
    }

    @Test("given 2 units all in 0–30 d, should say \"las 2 unidades llevan menos de 30 días en piso\"")
    func allFresh() {
        #expect(AgingSentence.text(lots: [lot(2, age: 3)]) == "las 2 unidades llevan menos de 30 días en piso")
    }

    @Test("given 1 fresh unit, should be singular")
    func oneUnit() {
        #expect(AgingSentence.text(lots: [lot(1, age: 3)]) == "la unidad lleva menos de 30 días en piso")
    }

    @Test("given 1 of 3 units over 90 days, should name the old ones")
    func someOld() {
        #expect(AgingSentence.text(lots: [lot(2, age: 10), lot(1, age: 120)]) == "1 de 3 unidades lleva más de 90 días")
    }

    @Test("given all units over 90 days, should say all of them")
    func allOld() {
        #expect(AgingSentence.text(lots: [lot(4, age: 100)]) == "las 4 unidades llevan más de 90 días")
    }

    @Test("given 2 of 5 units at 31–90 days and none older, should name the slow ones")
    func someSlow() {
        #expect(AgingSentence.text(lots: [lot(3, age: 10), lot(2, age: 45)]) == "2 de 5 unidades llevan entre 31 y 90 días")
    }

    @Test("given no units on hand (empty lots ignored), should be nil")
    func empty() {
        #expect(AgingSentence.text(lots: [lot(0, age: 200)]) == nil)
    }
}
