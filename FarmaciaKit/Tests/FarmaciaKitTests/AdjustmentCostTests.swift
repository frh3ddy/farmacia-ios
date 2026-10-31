import Testing
@testable import FarmaciaKit

struct AdjustmentCostTests {
    @Test("given found stock, should ask for a unit cost")
    func foundAsks() {
        #expect(AdjustmentCost.asksForCost(isNegative: false, isVariable: false, countChange: nil))
    }

    @Test("given damage, should not ask for a cost (the API costs removals by FIFO)")
    func damageDoesNotAsk() {
        #expect(!AdjustmentCost.asksForCost(isNegative: true, isVariable: false, countChange: nil))
    }

    @Test(
        "given a count correction, should ask for a cost only when the count adds stock",
        arguments: [(5, true), (-3, false), (nil, false)] as [(Int?, Bool)]
    )
    func countAsksWhenAdding(change: Int?, asks: Bool) {
        #expect(AdjustmentCost.asksForCost(isNegative: false, isVariable: true, countChange: change) == asks)
    }
}
