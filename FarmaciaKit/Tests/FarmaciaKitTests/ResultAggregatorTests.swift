import Foundation
import Testing
@testable import FarmaciaKit

struct ResultAggregatorTests {
    private let x = BarcodeCandidate(symbology: .ean13, payload: "4006381333931", confidence: 0.9)
    private let y = BarcodeCandidate(symbology: .ean8, payload: "96385074", confidence: 0.9)
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    /// Feeds frames 1/30 s apart from `start`; returns what each frame accepted.
    private func feed(_ agg: inout ResultAggregator, _ frames: [[BarcodeCandidate]], from start: Date) -> [String?] {
        frames.enumerated().map { agg.ingest($1, now: start.addingTimeInterval(Double($0) / 30)) }
    }

    // MARK: Voting (step 6)

    @Test("given one frame reading X, should not accept")
    func oneFrame() {
        var agg = ResultAggregator(settings: ScanSettings())
        #expect(agg.ingest([x], now: t0) == nil)
    }

    @Test("given X in 2 frames inside the last 10, should accept X on the second")
    func twoFrames() {
        var agg = ResultAggregator(settings: ScanSettings())
        #expect(feed(&agg, [[x], [], [], [x]], from: t0) == [nil, nil, nil, x.payload])
    }

    @Test("given X twice but 11 frames apart, should not accept")
    func outsideWindow() {
        var agg = ResultAggregator(settings: ScanSettings())
        let frames = [[x]] + Array(repeating: [BarcodeCandidate](), count: 10) + [[x]]
        #expect(feed(&agg, frames, from: t0).allSatisfy { $0 == nil })
    }

    @Test("given 3 votes required, should accept on the third frame")
    func threeVotes() {
        var settings = ScanSettings()
        settings.votesRequired = 3
        var agg = ResultAggregator(settings: settings)
        #expect(feed(&agg, [[x], [x], [x]], from: t0) == [nil, nil, x.payload])
    }

    @Test("given X below the minimum confidence, should not count its votes")
    func lowConfidence() {
        var agg = ResultAggregator(settings: ScanSettings())
        let weak = BarcodeCandidate(symbology: .ean13, payload: x.payload, confidence: 0.5)
        #expect(feed(&agg, [[weak], [weak], [weak]], from: t0).allSatisfy { $0 == nil })
    }

    @Test("given a wrong check digit, should not count it and should add one misread per read")
    func misread() {
        var agg = ResultAggregator(settings: ScanSettings())
        let bad = BarcodeCandidate(symbology: .ean13, payload: "4006381333932", confidence: 0.9)
        #expect(feed(&agg, [[bad], [bad]], from: t0) == [nil, nil])
        #expect(agg.misreads == 2)
    }

    @Test("given a symbology that isn't enabled, should not count it nor call it a misread")
    func disabledSymbology() {
        var agg = ResultAggregator(settings: ScanSettings())
        let itf = BarcodeCandidate(symbology: .itf14, payload: "00012345600012", confidence: 0.9)
        #expect(feed(&agg, [[itf], [itf]], from: t0) == [nil, nil])
        #expect(agg.misreads == 0)
    }

    @Test("given a 14-digit read and a 13-digit read of the same EAN-13, should count them as one code")
    func normalizedVotes() {
        var agg = ResultAggregator(settings: ScanSettings())
        let long = BarcodeCandidate(symbology: .ean13, payload: "0" + x.payload, confidence: 0.9)
        #expect(feed(&agg, [[long], [x]], from: t0) == [nil, x.payload])
    }

    // A code is accepted the moment it has enough votes, so two codes can only get there
    // in the same frame with the same count.
    @Test("given X and Y reaching the votes in the same frame, should accept the one read with higher confidence")
    func tieGoesToConfidence() {
        var agg = ResultAggregator(settings: ScanSettings())
        let sureY = BarcodeCandidate(symbology: .ean8, payload: y.payload, confidence: 0.95)
        #expect(feed(&agg, [[x, y], [x, sureY]], from: t0) == [nil, y.payload])
    }

    // MARK: Cooldown (step 7)

    @Test("given X just accepted, X again 1.0 s later, should not accept")
    func withinCooldown() {
        var agg = ResultAggregator(settings: ScanSettings())
        _ = feed(&agg, [[x], [x]], from: t0)
        #expect(feed(&agg, [[x], [x], [x]], from: t0.addingTimeInterval(1.0)) == [nil, nil, nil])
    }

    @Test("given X accepted, X again 1.6 s later, should accept it once it has fresh votes")
    func afterCooldown() {
        var agg = ResultAggregator(settings: ScanSettings())
        _ = feed(&agg, [[x], [x]], from: t0)
        #expect(feed(&agg, [[x], [x]], from: t0.addingTimeInterval(1.6)) == [nil, x.payload])
    }

    @Test("given X accepted, Y 0.2 s later, should accept Y: the cooldown is per code")
    func perCode() {
        var agg = ResultAggregator(settings: ScanSettings())
        _ = feed(&agg, [[x], [x]], from: t0)
        #expect(feed(&agg, [[y], [y]], from: t0.addingTimeInterval(0.2)) == [nil, y.payload])
    }
}
