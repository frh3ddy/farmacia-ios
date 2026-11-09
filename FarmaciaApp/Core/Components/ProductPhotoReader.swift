import CoreImage
import FarmaciaKit
import Vision

/// What Vision reads from a new product's photo, as plain values for
/// FarmaciaKit's naming rules (`LabelName`, `Presentation`, `ObjectName`).
struct PhotoReading: Sendable {
    /// OCR lines, top to bottom, with their height relative to the photo.
    var lines: [LabelLine] = []
    /// VNClassifyImageRequest identifiers above 0.3 confidence, best first.
    var labels: [String] = []
    /// The subject's color (background excluded), when a subject was found.
    var color: ColorName?

    var labelName: String? { LabelName.pick(lines: lines) }
    var objectName: String? { ObjectName.spanish(labels: labels, color: color) }
    var presentation: String? { Presentation.read(lines: lines.map(\.text)) }
}

/// On-device Vision only (iPhone 13 Pro and up), off the main actor.
enum ProductPhotoReader {
    /// Off the main actor, and still a child of the caller's task (a detached task
    /// would keep running after a new photo cancels this one).
    @concurrent
    static func read(_ image: CGImage) async -> PhotoReading {
        readNow(image)
    }

    private nonisolated static func readNow(_ image: CGImage) -> PhotoReading {
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.recognitionLanguages = ["es-MX", "en-US"]
        text.usesLanguageCorrection = true
        let classify = VNClassifyImageRequest()
        let subject = VNGenerateForegroundInstanceMaskRequest()

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        // ponytail: the subject mask also runs in SubjectLifter; share it if photos feel slow.
        try? handler.perform([text, classify, subject])

        var reading = PhotoReading()
        reading.lines = (text.results ?? [])
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }  // Vision's origin is bottom-left
            .compactMap { obs in
                obs.topCandidates(1).first.map { LabelLine(text: $0.string, height: Double(obs.boundingBox.height)) }
            }
        reading.labels = (classify.results ?? [])
            .filter { $0.confidence > 0.3 }
            .prefix(5)
            .map(\.identifier)
        if let mask = subject.results?.first, !mask.allInstances.isEmpty,
           let cutout = try? mask.generateMaskedImage(ofInstances: mask.allInstances, from: handler, croppedToInstancesExtent: true),
           let rgb = DominantColor.average(rgba: rgbaBytes(of: CIImage(cvPixelBuffer: cutout))) {
            reading.color = ColorName.spanish(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
        return reading
    }

    /// The image scaled to 64×64 as RGBA bytes; the removed background stays transparent.
    private static func rgbaBytes(of image: CIImage) -> [UInt8] {
        let side = 64
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return [] }
        let scaled = image.transformed(by: CGAffineTransform(scaleX: CGFloat(side) / extent.width,
                                                             y: CGFloat(side) / extent.height)
            .translatedBy(x: -extent.minX, y: -extent.minY))
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        CIContext().render(scaled, toBitmap: &bytes, rowBytes: side * 4,
                           bounds: CGRect(x: 0, y: 0, width: side, height: side),
                           format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return bytes
    }
}
