import Testing
@testable import FarmaciaKit

struct BarcodeReadTests {
    private let all = Set(Symbology.allCases)

    @Test("given a valid read, should yield the code as the box prints it", arguments: [
        (Symbology.ean13, "4006381333931", "4006381333931"),
        (.ean13, "04006381333931", "4006381333931"), // the iPhone's 14-digit read of an EAN-13
        (.ean13, "0036000291452", "0036000291452"),  // a UPC-A, kept in the 13-digit form products are saved under
        (.ean13, "036000291452", "0036000291452"),   // a UPC-A reported unpadded: the same 13-digit form
        (.ean8, "96385074", "96385074"),
        (.upce, "04252614", "04252614"),             // validated through its UPC-A, reported as 8 digits
        (.itf14, "00012345600012", "00012345600012"),
        (.code128, "ABC-123 x", "ABC-123 x"),
    ])
    func valid(symbology: Symbology, payload: String, code: String) {
        #expect(BarcodeRead.validated(symbology: symbology, payload: payload, enabled: all) == .success(code))
    }

    @Test("given a wrong check digit, should reject it as a misread", arguments: [
        (Symbology.ean13, "4006381333932"),
        (.ean8, "96385075"),
        (.upce, "04252615"),
        (.itf14, "00012345600013"),
    ])
    func checkDigit(symbology: Symbology, payload: String) {
        #expect(BarcodeRead.validated(symbology: symbology, payload: payload, enabled: all) == .failure(.checkDigit))
    }

    @Test("given the wrong length or characters for the symbology, should reject it as malformed", arguments: [
        (Symbology.ean13, "96385074"),
        (.ean13, "14006381333931"), // 14 digits not starting with 0 aren't an EAN-13
        (.ean8, "4006381333931"),
        (.upce, "24252614"),
        (.code128, ""),
        (.code128, "AB\u{01}C"),
        (.code39, "ABC\u{7F}"),
    ])
    func malformed(symbology: Symbology, payload: String) {
        #expect(BarcodeRead.validated(symbology: symbology, payload: payload, enabled: all) == .failure(.malformed))
    }

    @Test("given a symbology that isn't enabled, should reject it")
    func notEnabled() {
        #expect(BarcodeRead.validated(symbology: .code39, payload: "ABC", enabled: [.ean13]) == .failure(.notEnabled))
    }
}
