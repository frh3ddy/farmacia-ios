import Foundation

// MARK: - Scan region of interest
//
// The on-screen scan box → Vision's `regionOfInterest`. The box comes from
// `metadataOutputRectConverted(fromLayerRect:)`: normalized, top-left origin, in the
// sensor buffer's own orientation. Vision runs on that buffer as-is (orientation .up;
// its barcode detector reads any rotation), so only the y axis flips to Vision's
// bottom-left origin.

public enum ScanROI {
    public static func visionRect(fromMetadataRect rect: CGRect) -> CGRect {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let r = rect.intersection(unit)
        guard !r.isNull, !r.isEmpty else { return unit }
        return CGRect(x: r.minX, y: 1 - r.minY - r.height, width: r.width, height: r.height)
    }
}
