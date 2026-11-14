import Foundation

/// A segmented bar's widths (the detail's aging bar): each non-empty segment at least
/// `minimum` wide, the rest shared by fraction, so the bar is exactly `total` wide
/// (no overflow hidden by clipping). Empty fractions get 0 and no spacing.
public enum BarSegments {
    public static func widths(fractions: [Double], total: Double, spacing: Double, minimum: Double) -> [Double] {
        let shown = fractions.filter { $0 > 0 }
        let sum = shown.reduce(0, +)
        guard sum > 0 else { return fractions.map { _ in 0 } }
        let available = max(0, total - spacing * Double(shown.count - 1))
        let isSmall = { (f: Double) in f / sum * available < minimum }
        let rest = available - minimum * Double(shown.filter(isSmall).count)
        let largeSum = shown.filter { !isSmall($0) }.reduce(0, +)
        return fractions.map { f in
            guard f > 0 else { return 0 }
            return isSmall(f) ? minimum : f / largeSum * rest
        }
    }
}
