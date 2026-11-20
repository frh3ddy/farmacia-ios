import CoreGraphics
import CoreImage
import CoreText
import Foundation
import Testing
import FarmaciaKit
@testable import FarmaciaScan

/// Clean rendered labels, so the tests need no committed photos; real photos go through
/// `lot-bench` (lot OCR lab epic, step 9).
/// Serialized: each Vision read blocks its thread on Vision's own queue, and with one case per
/// filter running in parallel they took every thread and deadlocked (the app reads one frame
/// at a time, so it never does this).
@Suite(.serialized)
struct LotTextReaderTests {
    let reader = LotTextReader()
    let today = MonthYear(year: 2026, month: 11)
    let whole = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Black text lines on white, top line first.
    private func label(_ lines: [String], width: Int = 900, height: Int = 400) -> CIImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, 56, nil)
        for (i, text) in lines.enumerated() {
            let attributed = NSAttributedString(string: text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
            ])
            ctx.textPosition = CGPoint(x: 40, y: CGFloat(height) - 100 - CGFloat(i) * 90)
            CTLineDraw(CTLineCreateWithAttributedString(attributed), ctx)
        }
        return CIImage(cgImage: ctx.makeImage()!)
    }

    @Test("given a two-line label, should read its lines top to bottom")
    func readsInOrder() throws {
        let lines = try reader.read(label(["LOTE: D26U908", "CAD: JUL 28"]), roi: whole, orientation: .up, filter: .plain)
        #expect(lines == ["LOTE: D26U908", "CAD: JUL 28"])
    }

    @Test("given each filter, should still read the caducidad", arguments: LotFilter.allCases)
    func everyFilter(filter: LotFilter) throws {
        let lines = try reader.read(label(["LOTE: D26U908", "CAD: JUL 28"]), roi: whole, orientation: .up, filter: filter)
        #expect(LotScan(lines: lines, barcodes: [], today: today).expiry == MonthYear(year: 2028, month: 7))
    }

    @Test("given a frame turned 90°, should read its lines in order once turned upright", arguments: [
        (CGImagePropertyOrientation.left, CGImagePropertyOrientation.right),
        (CGImagePropertyOrientation.right, CGImagePropertyOrientation.left),
    ])
    func sensorRotation(turned: CGImagePropertyOrientation, back: CGImagePropertyOrientation) throws {
        // Vision reads sideways text by itself, but the line order comes from upright boxes.
        // The portrait back camera delivers the first case and passes .right.
        let sensor = label(["LOTE: D26U908", "CAD: JUL 28"]).oriented(turned)
        let lines = try reader.read(sensor, roi: whole, orientation: back, filter: .plain)
        #expect(lines == ["LOTE: D26U908", "CAD: JUL 28"])
    }

    @Test("given a scan box that leaves the text out, should read nothing")
    func outsideBox() throws {
        // The text sits in the top half; Vision's ROI origin is bottom-left.
        let lines = try reader.read(label(["CAD: JUL 28"]), roi: CGRect(x: 0, y: 0, width: 1, height: 0.4),
                                    orientation: .up, filter: .plain)
        #expect(lines.isEmpty)
    }
}
