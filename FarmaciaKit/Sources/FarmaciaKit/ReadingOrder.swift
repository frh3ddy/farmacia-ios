import CoreGraphics
import Foundation

// MARK: - Reading Order
//
// Live text reports text blocks in no particular order. The lot and expiry
// readers look at neighbouring lines (a lote printed above its caducidad), so
// the blocks are read like a page: rows top to bottom, each row left to right.

public enum ReadingOrder {
    /// Each block's transcript (it may hold several lines) and where it is in view.
    public static func lines(_ blocks: [(text: String, frame: CGRect)]) -> [String] {
        var rows: [[(text: String, frame: CGRect)]] = []
        for block in blocks.sorted(by: { $0.frame.midY < $1.frame.midY }) {
            // Same row: centres closer than half the shorter block's height (print is rarely level).
            if let last = rows.last?.last,
               abs(block.frame.midY - last.frame.midY) < min(block.frame.height, last.frame.height) / 2 {
                rows[rows.count - 1].append(block)
            } else {
                rows.append([block])
            }
        }
        return rows.flatMap { row in
            row.sorted { $0.frame.minX < $1.frame.minX }
                .flatMap { $0.text.components(separatedBy: .newlines) }
        }
    }
}
