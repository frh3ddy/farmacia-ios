import Foundation
import Testing
@testable import FarmaciaKit

struct SightingClockTests {
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func code(_ confidence: Float) -> [BarcodeCandidate] {
        [BarcodeCandidate(symbology: .ean13, payload: "4006381333931", confidence: confidence)]
    }

    @Test("given frames with no barcode, should have no sighting and no confidence")
    func nothingSeen() {
        var clock = SightingClock(gapFrames: 3)
        clock.frame([], now: t0)
        clock.frame([], now: t0 + 1)
        #expect(clock.since == nil)
        #expect(clock.topConfidence == nil)
    }

    @Test("given a code first seen at low confidence, should time from that frame and keep the best confidence")
    func firstSighting() {
        var clock = SightingClock(gapFrames: 3)
        clock.frame([], now: t0)
        clock.frame(code(0.2), now: t0 + 1)
        clock.frame(code(0.7), now: t0 + 2)
        clock.frame(code(0.4), now: t0 + 3)
        #expect(clock.since == t0 + 1)
        #expect(clock.topConfidence == 0.7)
    }

    @Test("given a short gap, should keep timing from the first sighting")
    func shortGap() {
        var clock = SightingClock(gapFrames: 3)
        clock.frame(code(0.5), now: t0)
        clock.frame([], now: t0 + 1)
        clock.frame([], now: t0 + 2)
        clock.frame(code(0.5), now: t0 + 3)
        #expect(clock.since == t0)
    }

    @Test("given the code out of view for the gap, should restart at the next sighting but keep the best confidence")
    func longGap() {
        var clock = SightingClock(gapFrames: 3)
        clock.frame(code(0.9), now: t0)
        for i in 1...3 { clock.frame([], now: t0 + Double(i)) }
        #expect(clock.since == nil)
        clock.frame(code(0.5), now: t0 + 4)
        #expect(clock.since == t0 + 4)
        #expect(clock.topConfidence == 0.9)
    }
}
