import Foundation

// MARK: - Offline benchmark summary
//
// `swift run scan-bench <folder>` runs each photo through a detector and summarizes it
// here. The expected code is in the filename, after the last underscore
// (`shiny-curved_4006381333931.jpg`); `_none` marks a photo with no code to read.

public struct BenchReport: Equatable, Sendable {
    public struct Result: Equatable, Sendable {
        /// nil: the photo has no code.
        public var expected: String?
        /// What the detector accepted, if anything.
        public var read: String?
        public var ms: Double

        public init(expected: String?, read: String?, ms: Double) {
            self.expected = expected
            self.read = read
            self.ms = ms
        }
    }

    public let images: Int
    public let hits: Int
    /// Accepted reads that aren't the expected code (including any read off a `_none` photo).
    public let misreads: Int
    /// Hits over the photos that have a code.
    public let readRate: Double
    public let medianMS: Double
    public let meanMS: Double

    public init(_ results: [Result]) {
        let coded = results.filter { $0.expected != nil }.count
        images = results.count
        hits = results.filter { $0.read != nil && $0.read == $0.expected }.count
        misreads = results.filter { $0.read != nil && $0.read != $0.expected }.count
        readRate = coded == 0 ? 0 : Double(hits) / Double(coded)
        let times = results.map(\.ms).sorted()
        let mid = times.count / 2
        medianMS = times.isEmpty ? 0 : times.count.isMultiple(of: 2) ? (times[mid - 1] + times[mid]) / 2 : times[mid]
        meanMS = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)
    }

    public static func expectedCode(fromFilename name: String) -> String? {
        let stem = (name as NSString).deletingPathExtension
        guard let underscore = stem.lastIndex(of: "_") else { return nil }
        let code = String(stem[stem.index(after: underscore)...])
        return code == "none" || code.isEmpty ? nil : code
    }
}
