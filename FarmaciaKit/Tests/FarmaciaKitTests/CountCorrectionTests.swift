import Testing
@testable import FarmaciaKit

struct CountCorrectionTests {
    @Test("given counted 12 and current 15, should preview a change of -3")
    func fewerOnShelf() {
        #expect(CountCorrection.preview(counted: 12, current: 15) == -3)
    }

    @Test("given counted equal to current, should preview nothing to save")
    func matches() {
        #expect(CountCorrection.preview(counted: 15, current: 15) == nil)
    }

    @Test("given current stock not loaded yet, should preview nothing to save")
    func unknownStock() {
        #expect(CountCorrection.preview(counted: 15, current: nil) == nil)
    }

    @Test("given no count typed, should preview nothing to save")
    func noCount() {
        #expect(CountCorrection.preview(counted: nil, current: 15) == nil)
    }

    @Test("given counted equal to the loaded stock, should be a match (nothing to save, but an answer)")
    func countMatchesStock() {
        #expect(CountCorrection.matches(counted: 15, current: 15))
    }

    @Test("given a different count, no count, or stock not loaded, should not be a match",
          arguments: [(Int?(12), Int?(15)), (nil, 15), (15, nil)])
    func noMatch(counted: Int?, current: Int?) {
        #expect(!CountCorrection.matches(counted: counted, current: current))
    }
}
