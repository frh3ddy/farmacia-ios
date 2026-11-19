import Foundation

// MARK: - Sighting clock
//
// Times a scan from the first frame where the detector sees any code in the box (at
// any confidence, before validation and voting) instead of from the camera opening,
// so the number measures the scanner rather than how long a box took to pick up.

public struct SightingClock: Sendable {
    /// Consecutive empty frames after which the code counts as gone and the clock restarts.
    public let gapFrames: Int
    /// The first frame of the current sighting; nil while nothing is in view.
    public private(set) var since: Date?
    /// The best confidence seen since the scanner opened (also across gaps).
    public private(set) var topConfidence: Float?
    private var emptyFrames = 0

    public init(gapFrames: Int) {
        self.gapFrames = gapFrames
    }

    public mutating func frame(_ candidates: [BarcodeCandidate], now: Date) {
        guard let best = candidates.map(\.confidence).max() else {
            emptyFrames += 1
            if emptyFrames >= gapFrames { since = nil }
            return
        }
        emptyFrames = 0
        if since == nil { since = now }
        topConfidence = max(topConfidence ?? best, best)
    }
}
