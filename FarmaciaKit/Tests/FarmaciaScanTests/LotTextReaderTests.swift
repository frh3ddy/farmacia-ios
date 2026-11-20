import CoreGraphics
import CoreImage
import CoreText
import Foundation
import Testing
import FarmaciaKit
@testable import FarmaciaScan

/// Clean rendered labels for the reader's mechanics; three small real crops (Photos/) for
/// the embossing filters. Read rates over many photos go through `lot-bench` (epic, step 9).
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

/// Blind-embossed boxes (no ink, only relief): label crops of photos IMG_5843, 5844 and 5846
/// (2026-11-20), 5843 and 5844 cut at about the size a 1080p frame gives the label.
extension LotTextReaderTests {
    private func photo(_ name: String) throws -> CIImage {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Photos"))
        return try #require(CIImage(contentsOf: url))
    }

    private func scan(_ name: String, _ filter: LotFilter) throws -> LotScan {
        LotScan(lines: try reader.read(photo(name), roi: whole, orientation: .up, filter: filter), barcodes: [], today: today)
    }

    @Test("given shallow embossing under flat light (IMG_5844), the deep relief filter should read NOV 27")
    func deepRelief() throws {
        #expect(try scan("emboss-5844", .deepRelief).expiry == MonthYear(year: 2027, month: 11))
    }

    /// The full-size crop (~4K frame size): plain reads 26010513, the other filters less.
    @Test("given embossing whose 5s read as 3s (IMG_5846), the darkened filter should read the lote right")
    func darkened() throws {
        #expect(try reader.read(photo("emboss-5846"), roi: whole, orientation: .up, filter: .darkened).contains("26010515"))
    }

    @Test("given embossing with SEP read as SEB (IMG_5843), should read September 2027")
    func sepAsSeb() throws {
        #expect(try scan("emboss-5843", .plain).expiry == MonthYear(year: 2027, month: 9))
    }
}

/// GS1 codes (DataMatrix on many boxes): exact lote and date, read alongside the text.
/// Core Image draws no DataMatrix, so a QR carries the payload; the symbology is a parameter.
extension LotTextReaderTests {
    private func qr(_ payload: String, size: CGFloat = 600) -> CIImage {
        let code = CIFilter(name: "CIQRCodeGenerator", parameters: ["inputMessage": Data(payload.utf8)])!.outputImage!
        let scaled = code.transformed(by: .init(scaleX: size / code.extent.width, y: size / code.extent.height))
        // A white margin, as on a box.
        return scaled.transformed(by: .init(translationX: 100, y: 100))
            .composited(over: CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: size + 200, height: size + 200)))
    }

    @Test("given a GS1 code in the box, should return its payload, which reads as lote and date")
    func codeInBox() throws {
        let payload = "0107501234567890" + "17280731" + "10D26U908"
        let codes = try reader.codes(qr(payload), roi: whole, symbologies: [.qr])
        #expect(codes == [payload])
        #expect(LotScan(lines: [], barcodes: codes, today: today) == LotScan(lot: "D26U908", expiry: MonthYear(year: 2028, month: 7)))
    }

    @Test("given a QR and the default (DataMatrix only), should return nothing: other codes never feed the lote (review dev-f8)")
    func otherSymbology() throws {
        #expect(try reader.codes(qr("0107501234567890" + "17280731" + "10D26U908"), roi: whole).isEmpty)
    }

    @Test("given the code outside the scan box, should return nothing")
    func codeOutsideBox() throws {
        let image = qr("0107501234567890" + "17280731" + "10D26U908")
        #expect(try reader.codes(image, roi: CGRect(x: 0, y: 0, width: 0.1, height: 0.1), symbologies: [.qr]).isEmpty)
    }
}
