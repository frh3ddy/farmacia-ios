import Testing
@testable import FarmaciaKit

struct StockChangeTests {
    @Test("given a count correction that removed 3 units, should be a removal")
    func negativeIsRemoval() {
        #expect(StockChange(quantity: -3) == .removed)
    }

    @Test("given found stock of 5 or a zero change, should be added or none", arguments: [(5, StockChange.added), (0, .none)])
    func positiveAndZero(quantity: Int, expected: StockChange) {
        #expect(StockChange(quantity: quantity) == expected)
    }
}
