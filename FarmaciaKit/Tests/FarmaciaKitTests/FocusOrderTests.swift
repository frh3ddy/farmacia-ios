import Foundation
import Testing
@testable import FarmaciaKit

/// The keyboard toolbar's ‹ › and the return key walk a form's fields in order;
/// past either end there's nowhere to go (Done closes the keyboard).
struct FocusOrderTests {
    let order = FocusOrder(["name", "price", "cost"])

    @Test("given the last field, next should be nil (Done)")
    func lastField() {
        #expect(order.next(after: "cost") == nil)
    }

    @Test("given a middle field, next and previous should be its neighbours")
    func middleField() {
        #expect(order.next(after: "price") == "cost")
        #expect(order.previous(before: "price") == "name")
    }

    @Test("given the first field, previous should be nil")
    func firstField() {
        #expect(order.previous(before: "name") == nil)
    }

    @Test("given a field that isn't in the form (hidden row), should go nowhere")
    func unknownField() {
        #expect(order.next(after: "supplier") == nil)
        #expect(order.previous(before: "supplier") == nil)
    }
}
