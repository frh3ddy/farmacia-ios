import Testing
@testable import FarmaciaKit

struct PriceSuggestionTests {
    @Test("given cost 12 and 30%, should be 17.50")
    func thirtyPercent() {
        #expect(PriceSuggestion.price(cost: 12, marginPercent: 30) == 17.50)
    }

    @Test("given an exact result, should not bump it to the next 50¢ (21 / 0.7 is 30.000000000000004)",
          arguments: [(12.0, 40.0, 20.0), (12.0, 50.0, 24.0), (21.0, 30.0, 30.0)])
    func exact(cost: Double, margin: Double, price: Double) {
        #expect(PriceSuggestion.price(cost: cost, marginPercent: margin) == price)
    }

    @Test("given a margin of 100% or more, or no positive cost, should suggest nothing",
          arguments: [(12.0, 100.0), (12.0, 120.0), (0.0, 40.0), (-1.0, 40.0)])
    func none(cost: Double, margin: Double) {
        #expect(PriceSuggestion.price(cost: cost, marginPercent: margin) == nil)
    }
}
