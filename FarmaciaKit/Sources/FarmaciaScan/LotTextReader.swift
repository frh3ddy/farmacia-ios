import CoreGraphics
import CoreImage
import FarmaciaKit
import Vision

// MARK: - Lot text reader
//
// One pass of the lab lot reader: crop the frame to the scan box, apply the pass's
// `LotFilter`, turn it upright and run Vision's text recognizer. Returns the lines in
// reading order (`ReadingOrder`), ready for `LotScan`.
//
// `roi` is the scan box in the buffer's own space (Vision's normalized bottom-left
// coordinates, like the barcode detector's). Unlike barcodes, text must be upright, so the
// caller passes how the frame is turned (portrait back camera: `.right`).
// The crop is fixed by the scan box; nothing here zooms into or re-captures what it finds
// (see LEGAL_REVIEW.md).

public final class LotTextReader: @unchecked Sendable {
    /// Thread-safe (Core Image); shared so every pass reuses its GPU resources.
    private let context = CIContext()

    public init() {}

    public func read(_ frame: CIImage, roi: CGRect, orientation: CGImagePropertyOrientation,
                     filter: LotFilter) throws -> [String] {
        let e = frame.extent
        let box = CGRect(x: e.minX + roi.minX * e.width, y: e.minY + roi.minY * e.height,
                         width: roi.width * e.width, height: roi.height * e.height).integral
        let crop = frame.cropped(to: box)
        let image = Self.apply(filter, to: crop.transformed(by: .init(translationX: -box.minX, y: -box.minY)))
            .oriented(orientation)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["es-MX", "en-US"]
        try VNImageRequestHandler(ciImage: image, options: [.ciContext: context]).perform([request])

        let blocks = (request.results ?? []).compactMap { o -> (text: String, frame: CGRect)? in
            guard let text = o.topCandidates(1).first?.string else { return nil }
            // Vision's box is bottom-left; ReadingOrder reads top-left like the screen.
            let b = o.boundingBox
            return (text, CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
        }
        return ReadingOrder.lines(blocks)
    }

    /// The Core Image recipe for each filter, sized to the crop (the Mac bench used 2–4 px
    /// dot growth and a 15 px unsharp radius on ~1,000–1,600 px label crops).
    static func apply(_ filter: LotFilter, to image: CIImage) -> CIImage {
        let scale = max(image.extent.width, image.extent.height) / 1000
        switch filter {
        case .plain:
            return image
        case .maxComponent:
            return image.applyingFilter("CIMaximumComponent")
        case .dotJoin:
            return image.applyingFilter("CIMaximumComponent")
                .applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: max(1, (2 * scale).rounded())])
        case .relief:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: max(2, 15 * scale), kCIInputIntensityKey: 3])
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 2])
        case .darkened:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 3])
        case .deepRelief:
            return image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: max(2, 25 * scale), kCIInputIntensityKey: 6])
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 3])
        }
    }
}
