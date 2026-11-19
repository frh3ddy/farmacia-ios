import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

// MARK: - Photo Vision
//
// The Vision half of Buscar por foto (tasks/photo-search-epic.md) and of the product
// photo flow's background removal. On CGImage, so it runs on the Mac too
// (`swift test`, `scan-bench`); the app's SubjectLifter wraps it for UIImage.

/// Background removal ("subject lifting") with Vision's foreground-instance mask.
public enum SubjectMask {
    /// The subject over white, the same size as `image`; nil when Vision finds no
    /// subject or fails. Synchronous: call it off the main actor.
    public static func lift(_ image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        guard (try? handler.perform([request])) != nil,
              let result = request.results?.first, !result.allInstances.isEmpty,
              let mask = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        else { return nil }

        let subject = CIImage(cgImage: image)
        let filter = CIFilter.blendWithMask()
        filter.inputImage = subject
        filter.backgroundImage = CIImage(color: .white).cropped(to: subject.extent)
        filter.maskImage = CIImage(cvPixelBuffer: mask)
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(output, from: subject.extent)
    }
}

/// Vision's image feature print as plain numbers (FarmaciaKit's `FeatureVector`).
public enum FeaturePrinter {
    /// Pinned, so stored vectors stay comparable; bump it (and FeatureIndex reindexes)
    /// only on purpose.
    public static let revision = VNGenerateImageFeaturePrintRequestRevision2

    /// Nil when Vision fails. Synchronous: call it off the main actor.
    public static func vector(_ image: CGImage) -> [Float]? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = revision
        guard (try? VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])) != nil,
              let print = request.results?.first, print.elementType == .float
        else { return nil }
        return print.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}

/// The text on a photographed box, for `PhotoSearch.textScore`. The same OCR settings
/// as the app's ProductPhotoReader (accurate, Spanish first).
public enum PhotoText {
    /// Recognized lines, top to bottom; empty when Vision reads nothing or fails.
    /// Synchronous: call it off the main actor.
    public static func lines(_ image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-MX", "en-US"]
        request.usesLanguageCorrection = true
        guard (try? VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])) != nil else { return [] }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}
