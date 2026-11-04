import Testing
@testable import FarmaciaKit

struct ReceivingFormTests {
    @Test("given quantity 0 and no cost, should list quantity then cost, and summarize \"Falta cantidad y costo\"")
    func issuesInOrder() {
        let issues = ReceivingForm.issues(quantity: 0, unitCost: nil, updatesPrice: false, newPrice: nil)
        #expect(issues == [.quantity, .cost])
        #expect(ReceivingForm.summary(issues) == "Falta cantidad y costo")
    }

    @Test("given all three missing, should summarize with a comma and y")
    func threeIssues() {
        let issues = ReceivingForm.issues(quantity: nil, unitCost: nil, updatesPrice: true, newPrice: nil)
        #expect(issues == [.quantity, .cost, .price])
        #expect(ReceivingForm.summary(issues) == "Falta cantidad, costo y precio")
    }

    @Test("given nothing missing, should have no issues and no summary")
    func noIssues() {
        let issues = ReceivingForm.issues(quantity: 3, unitCost: 0, updatesPrice: false, newPrice: nil)
        #expect(issues.isEmpty)
        #expect(ReceivingForm.summary(issues) == nil)
    }

    @Test("each issue says how to fix it, next to its field")
    func messages() {
        #expect(ReceivingForm.Issue.quantity.message == "Indica cuántas recibiste")
        #expect(ReceivingForm.Issue.cost.message == "Indica el costo unitario (0 si fue regalo)")
        #expect(ReceivingForm.Issue.price.message == "Indica el nuevo precio")
    }

    @Test("given the price update turned on with no price, should not allow saving")
    func priceOnButEmpty() {
        #expect(!ReceivingForm.canSave(quantity: 10, unitCost: 5, updatesPrice: true, newPrice: nil))
    }

    @Test("given the price update on, should allow saving only with a positive price",
          arguments: [(0.0, false), (25.0, true)])
    func priceMustBePositive(price: Double, allowed: Bool) {
        #expect(ReceivingForm.canSave(quantity: 10, unitCost: 5, updatesPrice: true, newPrice: price) == allowed)
    }

    @Test("given no price update, should need a quantity of at least 1 and a cost (zero allowed)",
          arguments: [(10, 5.0, true), (10, 0.0, true), (0, 5.0, false), (nil, 5.0, false), (10, nil, false)] as [(Int?, Double?, Bool)])
    func quantityAndCost(quantity: Int?, cost: Double?, allowed: Bool) {
        #expect(ReceivingForm.canSave(quantity: quantity, unitCost: cost, updatesPrice: false, newPrice: nil) == allowed)
    }
}
