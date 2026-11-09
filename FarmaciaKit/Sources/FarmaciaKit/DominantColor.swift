import Foundation

// MARK: - Dominant Color
//
// The photographed object's color: the average of the lifted subject's opaque
// pixels (RGBA bytes, the app downsizes the image first). The background that
// SubjectLifter removed is transparent and doesn't count.
// ponytail: plain average, so a two-tone object reads as the mix; k-means if
// that names colors wrong in practice.

public enum DominantColor {
    public struct RGB: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    public static func average(rgba: [UInt8]) -> RGB? {
        var sum = (r: 0, g: 0, b: 0), count = 0
        var i = 0
        while i + 3 < rgba.count {
            if rgba[i + 3] > 128 {
                sum.r += Int(rgba[i]); sum.g += Int(rgba[i + 1]); sum.b += Int(rgba[i + 2])
                count += 1
            }
            i += 4
        }
        guard count > 0 else { return nil }
        let scale = Double(count) * 255
        return RGB(red: Double(sum.r) / scale, green: Double(sum.g) / scale, blue: Double(sum.b) / scale)
    }
}
