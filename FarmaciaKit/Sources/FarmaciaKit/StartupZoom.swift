import Foundation

// MARK: - Startup zoom
//
// Apple's minimum-focus-distance approach (AVCamBarcode sample): a small code only fills
// the scan box when held closer than the lens can focus, so zoom in once at startup
// and the code can be held farther away, in focus. Set ONCE when the camera starts,
// never in response to a detection (see LEGAL_REVIEW.md).
//
// Geometry: at distance d the camera sees 2·d·tan(fov/2) across. The sample leaves out
// the 2; this doesn't.

public enum StartupZoom {
    /// - Parameters:
    ///   - minFocusMM: `AVCaptureDevice.minimumFocusDistance` (-1 when unknown).
    ///   - fovDegrees: field of view along the axis the code lies on.
    ///   - boxWidthFraction: how much of that axis the code should fill.
    public static func factor(minFocusMM: Double, fovDegrees: Double, codeWidthMM: Double,
                              boxWidthFraction: Double, maxZoom: Double) -> Double {
        guard minFocusMM > 0 else { return 1 }
        let halfAngle = fovDegrees / 2 * .pi / 180
        let fillDistance = codeWidthMM / boxWidthFraction / (2 * tan(halfAngle))
        return min(max(minFocusMM / fillDistance, 1), maxZoom)
    }
}
