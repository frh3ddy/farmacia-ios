import Testing
@testable import FarmaciaKit

struct ReceivingSubmitTests {
    @Test("given the supplier's cost still loading and no cost typed, should wait instead of reporting a missing cost")
    func waitsForCost() {
        #expect(ReceivingSubmit.action(isLoadingSupplierCost: true, unitCost: nil, issues: [.cost]) == .wait)
    }

    @Test("given a cost already typed, should not wait (the supplier's cost never overwrites it)")
    func typedCostDoesNotWait() {
        #expect(ReceivingSubmit.action(isLoadingSupplierCost: true, unitCost: 12, issues: []) == .save)
        #expect(ReceivingSubmit.action(isLoadingSupplierCost: true, unitCost: 12, issues: [.quantity]) == .showIssues)
    }

    @Test("given loading finished, should show what's missing, or save")
    func loaded() {
        #expect(ReceivingSubmit.action(isLoadingSupplierCost: false, unitCost: nil, issues: [.cost]) == .showIssues)
        #expect(ReceivingSubmit.action(isLoadingSupplierCost: false, unitCost: 0, issues: []) == .save)
    }
}
