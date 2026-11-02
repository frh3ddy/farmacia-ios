import Foundation
import Testing
@testable import FarmaciaKit

/// Margin is profit as a share of the selling price, shown on the create-product and
/// receiving forms.
struct MarginPercentTests {
    @Test("given price 100 and cost 80, should be 20%")
    func twentyPercent() {
        #expect(Margin.percent(price: 100, cost: 80) == 20)
    }

    @Test("given price 0, should be nil")
    func zeroPrice() {
        #expect(Margin.percent(price: 0, cost: 5) == nil)
    }
}

/// The margin preview's color: healthy from 20%, thin from 10%, too low below that.
struct MarginToneTests {
    @Test("given a 20% margin, should be positive")
    func healthy() {
        #expect(Margin.tone(forPercent: 20) == .positive)
    }

    @Test("given 10%, should be caution; given 9.9%, should be critical")
    func thinAndLow() {
        #expect(Margin.tone(forPercent: 10) == .caution)
        #expect(Margin.tone(forPercent: 9.9) == .critical)
    }
}
