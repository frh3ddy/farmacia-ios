import Foundation

// MARK: - Lot Filter
//
// The image filters the lab lot reader cycles through, one per pass: on the Mac bench
// (IMG_5793–5797) no single filter read every label, but together they read every
// field that was printed legibly. The Core Image recipes live in FarmaciaScan.

public enum LotFilter: String, CaseIterable, Sendable, Codable {
    /// The camera frame as is.
    case plain
    /// Each pixel's brightest channel: black ink stands out on a coloured cap.
    case maxComponent
    /// Brightest channel, then dark dots grown together: dot-matrix inkjet reads as strokes.
    case dotJoin
    /// Gray, unsharp mask and contrast: blind-embossed digits' shadows.
    case relief

    public static func forPass(_ pass: Int) -> LotFilter {
        allCases[pass % allCases.count]
    }
}
