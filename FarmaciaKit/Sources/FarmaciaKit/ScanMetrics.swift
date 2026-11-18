import Foundation

// MARK: - Scan metrics
//
// One row per accepted scan, for benchmarking scanners and settings on a device
// (DEBUG scanner screen → share CSV).

public struct ScanMetrics: Equatable, Sendable {
    public enum Detector: String, Sendable {
        case vision, preprocessed, zxing, ocr
        /// The old CodeScanner (AVCaptureMetadataOutput), the baseline.
        case legacy
    }

    public var date: Date
    /// `utsname` machine identifier, e.g. "iPhone16,1".
    public var device: String
    public var detector: Detector
    public var code: String
    /// From the scanner opening (or the previous accept) to this accept.
    public var msToRead: Int
    public var frames: Int
    /// Reads dropped for a wrong check digit before this accept.
    public var misreads: Int
    /// Which camera/preset/votes were in use, e.g. "wide-1080-v2".
    public var settingsTag: String

    public init(date: Date, device: String, detector: Detector, code: String,
                msToRead: Int, frames: Int, misreads: Int, settingsTag: String) {
        self.date = date
        self.device = device
        self.detector = detector
        self.code = code
        self.msToRead = msToRead
        self.frames = frames
        self.misreads = misreads
        self.settingsTag = settingsTag
    }

    public static func csv(_ scans: [ScanMetrics]) -> String {
        let header = "date,device,detector,code,ms_to_read,frames,misreads,settings"
        let rows = scans.map { s in
            [s.date.formatted(.iso8601), s.device, s.detector.rawValue, s.code,
             "\(s.msToRead)", "\(s.frames)", "\(s.misreads)", s.settingsTag]
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
