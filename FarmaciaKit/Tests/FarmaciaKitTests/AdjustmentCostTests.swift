import Testing
@testable import FarmaciaKit

struct AdjustmentCostTests {
    @Test("given found stock the API hasn't asked a cost for, should not show the cost field (it uses the last cost)")
    func foundNotAsked() {
        #expect(!AdjustmentCost.asksForCost(isNegative: false, isVariable: false, countChange: nil, costRequired: false))
    }

    @Test("given found stock after the API asked for a unit cost, should show the cost field")
    func foundAsked() {
        #expect(AdjustmentCost.asksForCost(isNegative: false, isVariable: false, countChange: nil, costRequired: true))
    }

    @Test("given damage, should never show a cost (the API costs removals by FIFO)")
    func damageDoesNotAsk() {
        #expect(!AdjustmentCost.asksForCost(isNegative: true, isVariable: false, countChange: nil, costRequired: true))
    }

    @Test(
        "given a count correction the API asked a cost for, should show it only while the count adds stock",
        arguments: [(5, true), (-3, false), (nil, false)] as [(Int?, Bool)]
    )
    func countAsksWhenAdding(change: Int?, asks: Bool) {
        #expect(AdjustmentCost.asksForCost(isNegative: false, isVariable: true, countChange: change, costRequired: true) == asks)
    }
}
