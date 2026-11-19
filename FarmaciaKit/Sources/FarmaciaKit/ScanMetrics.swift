import Foundation

// MARK: - Scan metrics
//
// One row per scanner opening — a read, or a give-up (closed without reading) so read
// rates can be computed — for benchmarking scanners and settings on a device
// (DEBUG scanner screen → share CSV).

public struct ScanMetrics: Equatable, Sendable, Codable {
    public enum Detector: String, Sendable, Codable {
        case vision, preprocessed, zxing, ocr
        /// The old CodeScanner (AVCaptureMetadataOutput), the baseline.
        case legacy
    }

    public var date: Date
    /// `utsname` machine identifier, e.g. "iPhone16,1".
    public var device: String
    public var detector: Detector
    /// nil when the scanner closed without reading anything.
    public var code: String?
    /// From the first frame with any code in the box to the accept (`SightingClock`);
    /// nil for give-ups and for the legacy scanner, which can't tell.
    public var msToRead: Int?
    /// From the scanner opening to the accept or the give-up (includes aiming).
    public var msSinceOpen: Int
    public var frames: Int
    /// Reads dropped for a wrong check digit.
    public var misreads: Int
    /// The best detector confidence seen, accepted or not; nil when nothing was seen.
    public var topConfidence: Float?
    /// Which camera/preset/votes were in use, e.g. "wide-1080-v2".
    public var settingsTag: String

    public init(date: Date, device: String, detector: Detector, code: String?, msToRead: Int?,
                msSinceOpen: Int, frames: Int, misreads: Int, topConfidence: Float?, settingsTag: String) {
        self.date = date
        self.device = device
        self.detector = detector
        self.code = code
        self.msToRead = msToRead
        self.msSinceOpen = msSinceOpen
        self.frames = frames
        self.misreads = misreads
        self.topConfidence = topConfidence
        self.settingsTag = settingsTag
    }

    public static func csv(_ scans: [ScanMetrics]) -> String {
        let header = "date,device,detector,outcome,code,ms_to_read,ms_since_open,frames,misreads,top_confidence,settings"
        let rows = scans.map { s in
            [s.date.formatted(.iso8601), s.device, s.detector.rawValue, s.code == nil ? "none" : "read",
             s.code ?? "", s.msToRead.map(String.init) ?? "", "\(s.msSinceOpen)", "\(s.frames)", "\(s.misreads)",
             s.topConfidence.map { String(format: "%.2f", $0) } ?? "", s.settingsTag]
                .map(csvField).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// RFC 4180: quote a field with a comma, quote or newline; double inner quotes.
    public static func csvField(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
