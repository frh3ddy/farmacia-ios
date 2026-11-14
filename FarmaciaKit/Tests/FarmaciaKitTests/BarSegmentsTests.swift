import Testing
@testable import FarmaciaKit

/// The aging bar on the product detail: one segment per age bucket, each at least
/// `minimum` wide so a sliver stays visible, the whole bar exactly `total` wide.
struct BarSegmentsTests {
    @Test("given 98% and 2% on a 100 pt bar with a 2 pt minimum and 1 pt spacing, should sum to 100 pt")
    func fitsTheBar() {
        let widths = BarSegments.widths(fractions: [0.98, 0.02], total: 100, spacing: 1, minimum: 2)
        #expect(widths == [97, 2])
        #expect(widths.reduce(0, +) + 1 == 100)
    }

    @Test("given one bucket, should fill the width")
    func oneBucket() {
        #expect(BarSegments.widths(fractions: [1], total: 100, spacing: 1, minimum: 2) == [100])
    }

    @Test("given a bucket with no units, should give it no segment and no spacing")
    func emptyBucket() {
        #expect(BarSegments.widths(fractions: [0.5, 0, 0.5], total: 101, spacing: 1, minimum: 2) == [50, 0, 50])
    }

    @Test("given no units at all, should give no segments")
    func nothing() {
        #expect(BarSegments.widths(fractions: [0, 0], total: 100, spacing: 1, minimum: 2) == [0, 0])
    }
}
