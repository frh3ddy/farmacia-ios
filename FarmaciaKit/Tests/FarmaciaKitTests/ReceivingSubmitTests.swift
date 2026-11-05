import Testing
@testable import FarmaciaKit

struct ReceivingSubmitTests {
    @Test("given the supplier's cost still loading and no cost typed, should wait instead of reporting a missing cost")
    func waitsForCost() {
        #expect(ReceivingSubmit.action(isLoadingProductSuppliers: true, isLoadingSupplierList: false,
                                       unitCost: nil, issues: [.cost]) == .wait)
    }

    @Test("given the product's suppliers loaded but not the supplier list (the preferred one can't be picked yet), should wait")
    func waitsForSupplierList() {
        #expect(ReceivingSubmit.action(isLoadingProductSuppliers: false, isLoadingSupplierList: true,
                                       unitCost: nil, issues: [.cost]) == .wait)
    }

    @Test("given a cost already typed, should not wait (the supplier's cost never overwrites it)")
    func typedCostDoesNotWait() {
        #expect(ReceivingSubmit.action(isLoadingProductSuppliers: true, isLoadingSupplierList: true,
                                       unitCost: 12, issues: []) == .save)
        #expect(ReceivingSubmit.action(isLoadingProductSuppliers: true, isLoadingSupplierList: true,
                                       unitCost: 12, issues: [.quantity]) == .showIssues(.quantity))
    }

    @Test("given loading finished, should show the first thing missing, or save")
    func loaded() {
        #expect(ReceivingSubmit.action(isLoadingProductSuppliers: false, isLoadingSupplierList: false,
                                       unitCost: nil, issues: [.cost, .quantity]) == .showIssues(.cost))
        #expect(ReceivingSubmit.action(isLoadingProductSuppliers: false, isLoadingSupplierList: false,
                                       unitCost: 0, issues: []) == .save)
    }
}
