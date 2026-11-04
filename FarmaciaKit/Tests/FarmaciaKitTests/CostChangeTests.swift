import Testing
@testable import FarmaciaKit

struct CostChangeTests {
    @Test("given current 17.90 and last 16.50, should be up 8% with caution tone")
    func up() throws {
        let change = try #require(CostChange(current: 17.90, last: 16.50))
        #expect(change.isUp)
        #expect(change.tone == .caution)
        #expect(change.text == "▲ 8% vs último $16.50")
    }

    @Test("given 15 vs 16.50, should be down with positive tone")
    func down() throws {
        let change = try #require(CostChange(current: 15, last: 16.50))
        #expect(!change.isUp)
        #expect(change.tone == .positive)
        #expect(change.text == "▼ 9% vs último $16.50")
    }

    @Test("given a change under half a percent, should say <1% rather than 0%")
    func tiny() throws {
        let change = try #require(CostChange(current: 100.30, last: 100))
        #expect(change.text == "▲ <1% vs último $100.00")
    }

    @Test("given no change, a change under 1¢, no current cost or no last cost, should be nil",
          arguments: [(16.50, 16.50), (16.505, 16.50), (nil, 16.50), (17.90, 0)] as [(Double?, Double)])
    func none(current: Double?, last: Double) {
        #expect(CostChange(current: current, last: last) == nil)
    }
}
