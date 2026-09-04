import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Automatic background removal for product photos ("subject lifting"),
/// using Vision's on-device foreground-instance segmentation (iOS 17+).
enum SubjectLifter {
    /// Composites the detected subject onto a white background. Falls back
    /// to the original image untouched if no clear subject is found or
    /// segmentation fails, so callers can always use the result directly.
    static func liftSubject(from image: UIImage) async -> UIImage {
        let normalized = image.imageOrientation == .up ? image : image.normalizedToUpOrientation()
        guard let cgImage = normalized.cgImage else { return image }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        do {
            try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else {
                return image
            }
            let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            return composite(cgImage: cgImage, mask: mask, scale: normalized.scale) ?? image
        } catch {
            return image
        }
    }

    private static func composite(cgImage: CGImage, mask: CVPixelBuffer, scale: CGFloat) -> UIImage? {
        let subject = CIImage(cgImage: cgImage)
        let maskImage = CIImage(cvPixelBuffer: mask)
        let background = CIImage(color: .white).cropped(to: subject.extent)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = subject
        filter.backgroundImage = background
        filter.maskImage = maskImage

        guard let output = filter.outputImage,
              let outputCGImage = CIContext().createCGImage(output, from: subject.extent)
        else { return nil }

        return UIImage(cgImage: outputCGImage, scale: scale, orientation: .up)
    }
}

private extension UIImage {
    /// Redraws the image with `.up` orientation so Vision/CoreImage see
    /// pixel data matching the image's visual appearance.
    func normalizedToUpOrientation() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
