import Testing
@testable import FarmaciaKit

struct ReceivingFormTests {
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
