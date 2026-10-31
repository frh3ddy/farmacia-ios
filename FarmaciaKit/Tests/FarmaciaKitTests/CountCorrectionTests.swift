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
}
