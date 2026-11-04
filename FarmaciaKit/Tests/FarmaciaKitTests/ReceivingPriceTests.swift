import Testing
@testable import FarmaciaKit

struct ReceivingPriceTests {
    @Test("given price 25, old cost 16.50, new cost 17.90, should keep the 34% margin at 27.50")
    func keepsMargin() {
        #expect(ReceivingPrice.keepingMargin(currentPrice: 25, oldCost: 16.50, newCost: 17.90) == 27.50)
    }

    @Test("given no current price, no old cost or no new cost, should be nil",
          arguments: [(nil, 16.50, 17.90), (25.0, nil, 17.90), (25.0, 16.50, nil)] as [(Double?, Double?, Double?)])
    func missing(price: Double?, old: Double?, new: Double?) {
        #expect(ReceivingPrice.keepingMargin(currentPrice: price, oldCost: old, newCost: new) == nil)
    }

    @Test("given the supplier's last cost, should use it as the old cost")
    func supplierFirst() {
        #expect(ReceivingPrice.oldCost(supplierLast: 16.50, average: 15) == 16.50)
    }

    @Test("given no supplier last cost, should use the average cost; given neither, nil")
    func fallback() {
        #expect(ReceivingPrice.oldCost(supplierLast: nil, average: 15) == 15)
        #expect(ReceivingPrice.oldCost(supplierLast: nil, average: nil) == nil)
    }
}
