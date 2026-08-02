import UIKit
import ImageIO

// MARK: - UIImage Resize (for uploads)

extension UIImage {
    /// Returns a resized copy whose longest edge is at most `maxDimension`
    /// pixels, or `nil` if resizing fails. Images already within the limit
    /// are returned unchanged (with orientation normalized).
    ///
    /// Rationale: a modern iPhone photo is 12–48 MP (~4032×3024 or larger).
    /// Uploading that at JPEG 0.8 produces 2–8 MB payloads on mobile data.
    /// Square POS and the app only ever display ≤ 1000 px, so 1600 px on the
    /// longest edge is a safe ceiling with headroom for zooming.
    func resizedForUpload(maxDimension: CGFloat = 1600) -> UIImage? {
        // Normalize orientation first so pixel dimensions are accurate
        let sourceImage = imageOrientation == .up ? self : normalizedOrientation()

        let width = sourceImage.size.width * sourceImage.scale
        let height = sourceImage.size.height * sourceImage.scale

        if max(width, height) <= maxDimension {
            return sourceImage
        }

        guard let cgImage = sourceImage.cgImage,
              let data = sourceImage.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        let options: CFDictionary = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let thumbnailOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let resizedCG = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: resizedCG)
    }

    /// JPEG data ready for upload: resized to the upload ceiling and
    /// compressed. Returns `nil` if the image can't be processed.
    func jpegDataForUpload(maxDimension: CGFloat = 1600,
                           compressionQuality: CGFloat = 0.8) -> Data? {
        let image = resizedForUpload(maxDimension: maxDimension) ?? self
        return image.jpegData(compressionQuality: compressionQuality)
    }

    /// Redraws the image with `.up` orientation.
    private func normalizedOrientation() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
