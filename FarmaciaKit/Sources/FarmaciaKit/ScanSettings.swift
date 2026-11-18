import Foundation

// MARK: - Scanner settings
//
// Every scanner threshold in one place. Defaults are the starting values to tune
// against the benchmark (README › Escáner); the DEBUG scanner screen edits them.

public struct ScanSettings: Equatable, Sendable {
    public enum Camera: String, CaseIterable, Sendable {
        /// The plain back wide camera.
        case wide
        /// Virtual devices that switch to the ultra-wide (macro) lens up close on Pro models.
        case dualWide, triple
    }

    public enum Preset: String, CaseIterable, Sendable {
        case hd1080, hd4K
    }

    public var symbologies: Set<Symbology> = [.ean13, .ean8, .upce, .code128]
    /// Vision observations below this confidence don't vote.
    public var minConfidence: Float = 0.6
    /// Frames the same code must appear in (2–3) before it's accepted.
    public var votesRequired: Int {
        get { votes }
        set { votes = min(max(newValue, 2), 3) }
    }
    private var votes = 2
    /// How many recent frames the votes are counted over.
    public var voteWindow = 10
    /// Seconds an accepted code is ignored before it can be accepted again.
    public var cooldown: TimeInterval = 1.5
    /// The scan box as a fraction of the preview, centered.
    public var scanBoxWidth = 0.8
    public var scanBoxHeight = 0.3
    /// The barcode width the startup zoom is sized for.
    public var targetCodeWidthMM = 35.0
    public var camera = Camera.wide
    public var preset = Preset.hd1080
    public var fps = 30

    public init() {}

    /// Labels metrics rows with the settings that produced them, e.g. "wide-1080-v2".
    public var tag: String {
        "\(camera.rawValue)-\(preset == .hd4K ? "4k" : "1080")-v\(votesRequired)"
    }
}
