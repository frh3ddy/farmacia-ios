import CoreGraphics
import FarmaciaKit
import Testing
@testable import FarmaciaScan

struct VisionBarcodeDetectorTests {
    private let detector = VisionBarcodeDetector(symbologies: ScanSettings().symbologies)
    private let whole = CGRect(x: 0, y: 0, width: 1, height: 1)

    @Test("given an EAN-13, should return it with its symbology")
    func ean13() throws {
        let reads = try detector.detect(in: SyntheticBarcode.image(code: "4006381333931"), roi: whole)
        #expect(reads.map(\.symbology) == [.ean13])
        #expect(reads.map(\.payload) == ["4006381333931"])
    }

    @Test("given an EAN-8, should return it with its symbology")
    func ean8() throws {
        let reads = try detector.detect(in: SyntheticBarcode.image(code: "96385074"), roi: whole)
        #expect(reads.map(\.symbology) == [.ean8])
        #expect(reads.map(\.payload) == ["96385074"])
    }

    @Test("given a QR beside an EAN-13, should return only the EAN-13")
    func ignoresQR() throws {
        let image = SyntheticBarcode.image(code: "4006381333931", qr: "https://example.com/lot/123")
        let reads = try detector.detect(in: image, roi: whole)
        #expect(reads.map(\.payload) == ["4006381333931"])
    }

    @Test("given an ROI that leaves out the code, should return nothing")
    func roiExcludes() throws {
        // Code on the left half, QR (not requested) on the right; look only at the right.
        let image = SyntheticBarcode.image(code: "4006381333931", qr: "x")
        let reads = try detector.detect(in: image, roi: CGRect(x: 0.55, y: 0, width: 0.45, height: 1))
        #expect(reads.isEmpty)
    }

    // UPC-A's bars are an EAN-13's with a leading 0. Vision (rev 4, macOS 14+) reports it as
    // .ean13 with all 13 digits; BarcodeRead also accepts an unpadded 12 in case a device differs.
    @Test("given a UPC-A, should read as .ean13 with 13 digits, which validates to the form products are saved under")
    func upcA() throws {
        let reads = try detector.detect(in: SyntheticBarcode.image(code: "0036000291452"), roi: whole)
        let read = try #require(reads.first)
        #expect(read.symbology == .ean13 && read.payload == "0036000291452")
        #expect(BarcodeRead.validated(symbology: read.symbology, payload: read.payload,
                                      enabled: ScanSettings().symbologies) == .success("0036000291452"))
    }
}
