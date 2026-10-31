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
}
