import Foundation

// MARK: - Color Name
//
// A photographed object's color in Spanish, for names like "Botella verde".
// Both genders, so the adjective agrees with the noun ("Oso … blanco",
// "Botella blanca"). Coarse buckets on hue, saturation and brightness: it
// names what a person would call the color, not a precise shade.

public struct ColorName: Equatable, Sendable {
    public let masculine: String
    public let feminine: String

    public init(masculine: String, feminine: String) {
        self.masculine = masculine
        self.feminine = feminine
    }

    private init(_ both: String) { self.init(masculine: both, feminine: both) }

    /// Components in 0...1.
    public static func spanish(red: Double, green: Double, blue: Double) -> ColorName {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        let value = maxC
        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC

        if value < 0.2 { return ColorName(masculine: "negro", feminine: "negra") }
        if saturation < 0.15 {
            return value > 0.85 ? ColorName(masculine: "blanco", feminine: "blanca") : ColorName("gris")
        }

        let hue = hueDegrees(red: red, green: green, blue: blue, maxC: maxC, delta: maxC - minC)
        switch hue {
        case 15..<40:
            return value < 0.6 ? ColorName("café") : ColorName("naranja")
        case 40..<70:
            return ColorName(masculine: "amarillo", feminine: "amarilla")
        case 70..<170:
            return ColorName("verde")
        case 170..<260:
            return ColorName("azul")
        case 260..<300:
            return ColorName(masculine: "morado", feminine: "morada")
        case 300..<345:
            return ColorName("rosa")
        default:
            return ColorName(masculine: "rojo", feminine: "roja")
        }
    }

    private static func hueDegrees(red: Double, green: Double, blue: Double, maxC: Double, delta: Double) -> Double {
        let h: Double
        if maxC == red {
            h = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxC == green {
            h = (blue - red) / delta + 2
        } else {
            h = (red - green) / delta + 4
        }
        let degrees = h * 60
        return degrees < 0 ? degrees + 360 : degrees
    }
}
