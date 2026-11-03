import Testing
@testable import FarmaciaKit

/// Stock and batch-age status by meaning, so product screens don't pick colors or cutoffs themselves.
/// Stock cutoffs match the API's list filters (outOfStock ≤ 0, lowStock 1–9).
struct StockLevelTests {
    @Test("given 0 on hand, should be out of stock and critical")
    func out() {
        #expect(StockLevel(quantity: 0) == .out)
        #expect(StockLevel.out.tone == .critical)
        #expect(StockLevel.out.label == "Agotado")
    }

    @Test("given 9 on hand, should be low and caution")
    func low() {
        #expect(StockLevel(quantity: 9) == .low)
        #expect(StockLevel(quantity: 1) == .low)
        #expect(StockLevel.low.tone == .caution)
        #expect(StockLevel.low.label == "Bajo")
    }

    @Test("given 10 on hand, should be ok, with no label")
    func ok() {
        #expect(StockLevel(quantity: 10) == .ok)
        #expect(StockLevel.ok.label == nil)
    }
}

struct BatchAgeTests {
    @Test("given a 29-day-old batch, should be positive")
    func fresh() { #expect(BatchAge.tone(days: 29) == .positive) }

    @Test("given 30 days, should be caution")
    func moderate() { #expect(BatchAge.tone(days: 30) == .caution) }

    @Test("given 90 days, should be critical")
    func old() { #expect(BatchAge.tone(days: 90) == .critical) }
}

struct ProductFilterToneTests {
    @Test("given each filter, should color it by what it means", arguments: [
        (ProductFilter.outOfStock, Tone.critical), (.atRisk, .critical),
        (.lowStock, .caution), (.expiringSoon, .caution), (.lowMargin, .caution),
        (.inStock, .positive), (.all, .info),
    ])
    func tone(filter: ProductFilter, tone: Tone) { #expect(filter.tone == tone) }
}
