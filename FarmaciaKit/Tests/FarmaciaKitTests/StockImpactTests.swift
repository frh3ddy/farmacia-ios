import Testing
@testable import FarmaciaKit

/// What a stock change will do, shown before Guardar: before → after and the signed change.
struct StockImpactTests {
    @Test("given 42 on hand and −3, should end at 39")
    func removal() throws {
        let impact = try #require(StockImpact(before: 42, change: -3))
        #expect(impact.after == 39)
        #expect(impact.summary == "42 → 39 (−3)")
        #expect(impact.tone == .critical)
        #expect(!impact.exceedsStock)
    }

    @Test("given an addition, should show a plus sign and be positive")
    func addition() throws {
        let impact = try #require(StockImpact(before: 5, change: 10))
        #expect(impact.summary == "5 → 15 (+10)")
        #expect(impact.tone == .positive)
    }

    @Test("given a removal larger than the stock, should flag it")
    func pastZero() throws {
        let impact = try #require(StockImpact(before: 2, change: -5))
        #expect(impact.exceedsStock)
    }

    @Test("given no change, should be nil")
    func noChange() {
        #expect(StockImpact(before: 42, change: 0) == nil)
        #expect(StockImpact(before: 42, change: nil) == nil)
    }

    @Test("given an unknown stock, should show only the change")
    func unknownBefore() throws {
        let impact = try #require(StockImpact(before: nil, change: -3))
        #expect(impact.after == nil)
        #expect(impact.summary == "−3 unidades")
        #expect(!impact.exceedsStock)
    }
}
