import Foundation

// MARK: - Tone
//
// What a value means (good, needs attention, bad), not what color it is. Rules
// in this package pick a tone; the app maps each tone to a color once
// (`Tone.color` in FarmaciaApp/Core/DesignSystem), so screens never decide
// "green" or "red" themselves.

public enum Tone: Sendable, Equatable {
    case positive
    case caution
    case critical
    case info
    case neutral
}
