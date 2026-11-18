import CoreGraphics
import CoreImage

// Renders clean EAN-13 / EAN-8 bars (GS1 encoding tables) and QR codes, so the detector
// tests need no committed photos. Real-world photos go through `scan-bench` instead.
enum SyntheticBarcode {
    private static let lCodes = ["0001101", "0011001", "0010011", "0111101", "0100011",
                                 "0110001", "0101111", "0111011", "0110111", "0001011"]
    private static let parity = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
                                 "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"]

    private static func r(_ d: Int) -> String { String(lCodes[d].map { $0 == "0" ? "1" : "0" }) }
    private static func g(_ d: Int) -> String { String(r(d).reversed()) }

    /// Modules (1 = bar) for an 8- or 13-digit code.
    static func modules(_ code: String) -> String {
        let d = code.compactMap(\.wholeNumberValue)
        if d.count == 8 {
            return "101" + d[0..<4].map { lCodes[$0] }.joined() + "01010" + d[4..<8].map(r).joined() + "101"
        }
        let left = zip(parity[d[0]], d[1...6]).map { $0 == "L" ? lCodes[$1] : g($1) }.joined()
        return "101" + left + "01010" + d[7...12].map(r).joined() + "101"
    }

    /// A white image with the barcode on the left half and, optionally, a QR on the right.
    static func image(code: String, qr: String? = nil, module: Int = 4, height: Int = 240) -> CGImage {
        let bars = modules(code)
        let quiet = 12 * module
        let barWidth = bars.count * module
        let width = (quiet * 2 + barWidth) * (qr == nil ? 1 : 2)
        let ctx = CGContext(data: nil, width: width, height: height + 80, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height + 80))
        ctx.setFillColor(gray: 0, alpha: 1)
        for (i, m) in bars.enumerated() where m == "1" {
            ctx.fill(CGRect(x: quiet + i * module, y: 40, width: module, height: height))
        }
        if let qr, let qrImage = qrCode(qr, side: height) {
            ctx.draw(qrImage, in: CGRect(x: width / 2 + quiet, y: 40, width: height, height: height))
        }
        return ctx.makeImage()!
    }

    private static func qrCode(_ text: String, side: Int) -> CGImage? {
        let filter = CIFilter(name: "CIQRCodeGenerator", parameters: ["inputMessage": Data(text.utf8)])!
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: .init(scaleX: CGFloat(side) / output.extent.width, y: CGFloat(side) / output.extent.height))
        return CIContext().createCGImage(scaled, from: scaled.extent)
    }
}
