import Foundation

// MARK: - Multi-frame voting
//
// A read is accepted only once the same validated code shows up in `votesRequired` of
// the last `voteWindow` frames (generic multi-frame voting; one bad frame can't produce
// a scan), then ignored for `cooldown` so holding it in view doesn't scan it twice.
// Reads that fail validation never vote; a wrong check digit counts as a misread.

public struct BarcodeCandidate: Equatable, Sendable {
    public var symbology: Symbology
    public var payload: String
    public var confidence: Float

    public init(symbology: Symbology, payload: String, confidence: Float) {
        self.symbology = symbology
        self.payload = payload
        self.confidence = confidence
    }
}

public struct ResultAggregator: Sendable {
    public let settings: ScanSettings
    /// Reads dropped for a wrong check digit since this scanner opened.
    public private(set) var misreads = 0
    /// Validated codes per recent frame, oldest first, with each code's best confidence.
    private var window: [[String: Float]] = []
    /// When each code was last accepted; it doesn't vote again until `cooldown` passes.
    private var acceptedAt: [String: Date] = [:]

    public init(settings: ScanSettings) {
        self.settings = settings
    }

    /// Adds one frame's reads; returns the code accepted on this frame, if any.
    public mutating func ingest(_ frame: [BarcodeCandidate], now: Date) -> String? {
        var codes: [String: Float] = [:]
        for read in frame where read.confidence >= settings.minConfidence {
            switch BarcodeRead.validated(symbology: read.symbology, payload: read.payload, enabled: settings.symbologies) {
            case .success(let code):
                if let last = acceptedAt[code], now.timeIntervalSince(last) < settings.cooldown { continue }
                codes[code] = max(codes[code] ?? 0, read.confidence)
            case .failure(.checkDigit): misreads += 1
            case .failure: break
            }
        }
        window.append(codes)
        if window.count > settings.voteWindow { window.removeFirst() }

        let ready = codes.filter { code, _ in window.count { $0[code] != nil } >= settings.votesRequired }
        guard let (code, _) = ready.max(by: { $0.value < $1.value }) else { return nil }
        // Fresh votes are needed to accept it again.
        for i in window.indices { window[i][code] = nil }
        acceptedAt[code] = now
        return code
    }
}
