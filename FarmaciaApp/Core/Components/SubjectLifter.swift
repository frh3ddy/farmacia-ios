import FarmaciaScan
import UIKit

/// Automatic background removal for product photos ("subject lifting"). The Vision
/// work is FarmaciaScan's `SubjectMask` (also used by Buscar por foto); this keeps the
/// UIImage side: orientation and scale.
enum SubjectLifter {
    /// Composites the detected subject onto a white background. Falls back
    /// to the original image untouched if no clear subject is found or
    /// segmentation fails, so callers can always use the result directly.
    static func liftSubject(from image: UIImage) async -> UIImage {
        let normalized = image.imageOrientation == .up ? image : image.normalizedToUpOrientation()
        guard let cgImage = normalized.cgImage, let lifted = SubjectMask.lift(cgImage) else { return image }
        return UIImage(cgImage: lifted, scale: normalized.scale, orientation: .up)
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
