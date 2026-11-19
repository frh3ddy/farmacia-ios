import FarmaciaKit
import FarmaciaScan
import Foundation
import ImageIO

// Buscar por foto benchmark (tasks/photo-search-epic.md, step 8). Each photo goes
// through what the app does: downsample, lift the subject (else the whole photo),
// OCR + feature print, then PhotoSearch.rank, scored as text only, looks only and both.

private struct Read {
    let lines: [String]
    let vector: [Float]?
}


/// Its own list: main.swift's top-level globals aren't set yet when this mode runs.
private let imageTypes: Set = ["jpg", "jpeg", "png", "heic"]

private func photos(in folder: String) -> [URL] {
    ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)) ?? [])
        .filter { imageTypes.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

/// Downsampled like the app's photo loader, so timings and reads are comparable.
private func load(_ url: URL, maxPixels: Int = 1024) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                    kCGImageSourceCreateThumbnailWithTransform: true,
                                    kCGImageSourceThumbnailMaxPixelSize: maxPixels]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}

private func read(_ image: CGImage) -> Read {
    let subject = SubjectMask.lift(image) ?? image
    return Read(lines: PhotoText.lines(subject), vector: FeaturePrinter.vector(subject))
}

func photoSearchBench(_ args: [String]) {
    let folders = args.filter { !$0.hasPrefix("-") && !$0.contains(",") }
    guard folders.count == 2 else {
        print("usage: swift run scan-bench --photo-search <refs> <queries> [--weights text,image,floor]")
        exit(2)
    }
    var weights = PhotoSearch.Weights.standard
    if let i = args.firstIndex(of: "--weights"), i + 1 < args.count {
        let w = args[i + 1].split(separator: ",").compactMap { Double($0) }
        guard w.count == 3 else { print("--weights takes text,image,floor"); exit(2) }
        weights = .init(text: w[0], image: w[1], unrelatedFloor: w[2])
    }

    var candidates: [PhotoSearch.Candidate] = []
    for url in photos(in: folders[0]) {
        guard let image = load(url) else { print("skipped (unreadable): \(url.lastPathComponent)"); continue }
        let name = PhotoBench.referenceName(fromFilename: url.lastPathComponent)
        candidates.append(.init(id: name, name: name, vector: read(image).vector))
    }

    var results: (text: [PhotoBench.Result], looks: [PhotoBench.Result], both: [PhotoBench.Result]) = ([], [], [])
    print("query,expected,both rank,same cos,best other cos,best other")
    for url in photos(in: folders[1]) {
        guard let expected = PhotoBench.expected(fromFilename: url.lastPathComponent) else {
            print("skipped (no _<product> in name): \(url.lastPathComponent)"); continue
        }
        guard candidates.contains(where: { $0.id == expected }) else {
            print("skipped (no reference named \(expected)): \(url.lastPathComponent)"); continue
        }
        guard let image = load(url) else { print("skipped (unreadable): \(url.lastPathComponent)"); continue }
        let query = read(image)
        func ranked(_ lines: [String], _ photo: [Float]?) -> PhotoBench.Result {
            .init(expected: expected, ranked: PhotoSearch.rank(candidates, lines: lines, photo: photo, weights: weights).map(\.id))
        }
        let both = ranked(query.lines, query.vector)
        results.text.append(ranked(query.lines, nil))
        results.looks.append(ranked([], query.vector))
        results.both.append(both)

        // For tuning the floor: the right product's similarity vs the closest wrong one.
        let cos = candidates.map { c in (c.id, query.vector.flatMap { q in c.vector.flatMap { FeatureVector.similarity(q, $0) } }) }
        let same = cos.first { $0.0 == expected }?.1
        let other = cos.filter { $0.0 != expected }.compactMap { id, s in s.map { (id, $0) } }.max { $0.1 < $1.1 }
        let position = (both.ranked.firstIndex(of: expected) ?? -1) + 1
        print([url.lastPathComponent, expected, String(position),
               same.map { String(format: "%.3f", $0) } ?? "", other.map { String(format: "%.3f", $0.1) } ?? "", other?.0 ?? ""]
            .map(ScanMetrics.csvField).joined(separator: ","))
    }

    func row(_ name: String, _ r: [PhotoBench.Result]) -> String {
        name.padding(toLength: 8, withPad: " ", startingAt: 0)
            + String(format: "%6.1f%%  %6.1f%%", PhotoBench.hitRate(r, top: 1) * 100, PhotoBench.hitRate(r, top: 5) * 100)
    }
    print("""

    \(candidates.count) references, \(results.both.count) queries; weights text \(weights.text), image \(weights.image), floor \(weights.unrelatedFloor)
    signal    top 1    top 5
    \(row("text", results.text))
    \(row("looks", results.looks))
    \(row("both", results.both))
    """)
}
