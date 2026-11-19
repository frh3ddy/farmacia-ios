import FarmaciaKit
import FarmaciaScan
import Foundation
import ImageIO

// Offline scanner benchmark: each photo in a folder through the detector, then a
// BenchReport. One photo is one frame, so there's no voting: the best validated read
// at or above ScanSettings' minimum confidence counts as the accept.

let usage = """
usage: swift run scan-bench <folder> [--csv | --list]

Photos (jpg, jpeg, png, heic) are named with the expected code LAST, after an
underscore: shiny-curved_4006381333931.jpg. Use _none for a photo with no code
(any read off it is a misread). --csv prints one row per photo instead of the summary.
--list ignores filenames (IMG_5756.HEIC is fine) and just prints what each photo reads,
to check by eye; no read rate, since there's no expected code.
"""

let args = CommandLine.arguments.dropFirst()
guard let folder = args.first(where: { !$0.hasPrefix("-") }) else {
    print(usage)
    exit(2)
}
let asCSV = args.contains("--csv")
let asList = args.contains("--list")

let settings = ScanSettings()
let detector = VisionBarcodeDetector(symbologies: settings.symbologies)
let wholeImage = CGRect(x: 0, y: 0, width: 1, height: 1)
let photoTypes: Set = ["jpg", "jpeg", "png", "heic"]

let files = ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? [])
    .filter { photoTypes.contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else {
    print("No photos in \(folder).\n\n\(usage)")
    exit(1)
}

// Vision's first request loads its model (~60 ms); keep that out of the first photo's time.
_ = try? detector.detect(in: CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!.makeImage()!, roi: wholeImage)

var results: [BenchReport.Result] = []
var listed = (read: 0, total: 0)
if asCSV { print("file,expected,read,ms") }
for url in files {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("skipped (unreadable): \(url.lastPathComponent)")
        continue
    }
    let start = ContinuousClock.now
    let reads = (try? detector.detect(in: image, roi: wholeImage)) ?? []
    let ms = (ContinuousClock.now - start) / .milliseconds(1)
    let read = reads
        .filter { $0.confidence >= settings.minConfidence }
        .sorted { $0.confidence > $1.confidence }
        .lazy.compactMap { try? BarcodeRead.validated(symbology: $0.symbology, payload: $0.payload, enabled: settings.symbologies).get() }
        .first
    if asList {
        // What a scanner would accept, else the best raw sighting (why it didn't count).
        let raw = reads.max { $0.confidence < $1.confidence }
        let detail = raw.map { "\($0.symbology.rawValue) \(String(format: "%.2f", $0.confidence))" } ?? ""
        listed.total += 1
        if let read {
            listed.read += 1
            print("✔ \(url.lastPathComponent): \(read)  (\(detail))")
        } else {
            print("✘ \(url.lastPathComponent): nothing\(raw.map { "  (saw \($0.payload), \(detail), not accepted)" } ?? "")")
        }
        continue
    }
    let expected = BenchReport.expectedCode(fromFilename: url.lastPathComponent)
    results.append(.init(expected: expected, read: read, ms: ms))
    if asCSV {
        print([url.lastPathComponent, expected ?? "", read ?? "", String(format: "%.1f", ms)].map(ScanMetrics.csvField).joined(separator: ","))
    } else if read != expected {
        print("✘ \(url.lastPathComponent): expected \(expected ?? "none"), read \(read ?? "nothing")")
    }
}

if asList {
    print("\nread \(listed.read) of \(listed.total) photos")
} else if !asCSV {
    let r = BenchReport(results)
    print("""

    detector   images  hits  misreads  read rate  median ms  mean ms
    vision     \(String(r.images).padding(toLength: 6, withPad: " ", startingAt: 0))  \
    \(String(r.hits).padding(toLength: 4, withPad: " ", startingAt: 0))  \
    \(String(r.misreads).padding(toLength: 8, withPad: " ", startingAt: 0))  \
    \(String(format: "%8.1f%%", r.readRate * 100))  \(String(format: "%9.1f", r.medianMS))  \(String(format: "%7.1f", r.meanMS))
    """)
}
