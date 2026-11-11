import Testing
@testable import FarmaciaKit

/// The fallback counts behind the Productos chips and the Alertas cards, when the
/// server's counts aren't in (cache-first, or GET /products/counts failed).
struct StockTallyTests {
    @Test("given a product at 0 that is paused, should count it as paused, not out of stock")
    func pausedAtZero() {
        let tally = StockTally([(0, StockAlert(level: .none, paused: true))])
        #expect(tally.paused == 1)
        #expect(tally.outOfStock == 0)
    }

    @Test("given a paused product that still has stock, should count it only as paused (same as the server)")
    func pausedWithStock() {
        let tally = StockTally([(5, StockAlert(level: .none, paused: true))])
        #expect(tally == StockTally(outOfStock: 0, lowStock: 0, inStock: 0, paused: 1))
    }

    @Test("given every product at 0, alerting or not, should count it as out of stock (Sin Stock is the stock state)")
    func outIncludesQuiet() {
        let tally = StockTally([
            (0, StockAlert(level: .out)), (0, StockAlert(level: .none)), (3, StockAlert(level: .low)),
            (2, StockAlert(level: .none)), (40, nil),
        ])
        #expect(tally == StockTally(outOfStock: 2, lowStock: 1, inStock: 2, paused: 0))
    }

    @Test("given an old server (no alerts), should keep the fixed cutoffs and have no paused count (no Pausados chip)")
    func fallback() {
        let tally = StockTally([(0, nil), (3, nil), (12, nil)])
        #expect(tally == StockTally(outOfStock: 1, lowStock: 1, inStock: 1, paused: nil))
    }
}
