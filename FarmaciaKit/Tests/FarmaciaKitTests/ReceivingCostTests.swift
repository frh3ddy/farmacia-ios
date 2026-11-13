import Testing
@testable import FarmaciaKit

struct ReceivingCostTests {
    @Test("given a cost entered for one product, should clear it when another product is picked")
    func clearsOnProductChange() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.value = 50
        cost.productChanged(to: "b")
        #expect(cost.value == nil)
    }

    @Test("given the same product picked again, should keep the cost")
    func keepsOnSameProduct() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.value = 30
        cost.productChanged(to: "a")
        #expect(cost.value == 30)
    }

    @Test("given an empty cost, should fill in the selected product's supplier cost")
    func fillsSupplierCost() {
        var cost = ReceivingCost()
        cost.productChanged(to: "b")
        let filled = cost.offerSupplierCost(12.5, forProductId: "b")
        #expect(filled)
        #expect(cost.value == 12.5)
    }

    @Test("given a supplier response for a product no longer selected, should ignore it")
    func ignoresStaleResponse() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.productChanged(to: "b")
        let filled = cost.offerSupplierCost(50, forProductId: "a")
        #expect(!filled)
        #expect(cost.value == nil)
    }

    @Test("given a cost already entered, should not overwrite it with the supplier's")
    func keepsEnteredCost() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.value = 30
        let filled = cost.offerSupplierCost(50, forProductId: "a")
        #expect(!filled)
        #expect(cost.value == 30)
    }

    @Test("given a supplier cost of zero or less, should leave the cost empty", arguments: [0.0, -1.0])
    func ignoresNonPositiveCost(supplierCost: Double) {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        let filled = cost.offerSupplierCost(supplierCost, forProductId: "a")
        #expect(!filled)
        #expect(cost.value == nil)
    }

    @Test("given a cost carried from Nuevo producto, should keep it after the supplier's last cost is offered")
    func carriedCostWins() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.prefill(20, forProductId: "a")
        cost.offerSupplierCost(50, forProductId: "a")
        #expect(cost.value == 20)
    }

    @Test("given a carried cost of 0 (a gift), should keep 0")
    func carriedZero() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.prefill(0, forProductId: "a")
        #expect(cost.value == 0)
    }

    @Test("given a carried cost for another product, should not fill")
    func carriedForOtherProduct() {
        var cost = ReceivingCost()
        cost.productChanged(to: "a")
        cost.prefill(20, forProductId: "b")
        #expect(cost.value == nil)
    }

    @Test("given a previous cost of 12.5, should hint \"Anterior 12.50\" (the field shows the $)")
    func hintsPreviousCost() {
        #expect(ReceivingCost.hint(previous: 12.5) == "Anterior 12.50")
        #expect(ReceivingCost.hint(previous: 1234.5) == "Anterior 1,234.50")
    }

    @Test("given no previous cost, should have no hint (the field keeps its placeholder)")
    func noHint() {
        #expect(ReceivingCost.hint(previous: nil) == nil)
    }
}
