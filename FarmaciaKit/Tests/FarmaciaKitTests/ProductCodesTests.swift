import Testing
@testable import FarmaciaKit

struct ProductCodesTests {
    @Test("given a barcode that's the SKU with a leading zero, should give one line")
    func sameCode() {
        #expect(ProductCodes.lines(sku: "3664798067460", gtin: "03664798067460") == [.sku("3664798067460")])
    }

    @Test("given a SKU and a different barcode, should give both, SKU first")
    func both() {
        #expect(ProductCodes.lines(sku: "8857379", gtin: "3664798067460") == [.sku("8857379"), .barcode("3664798067460")])
    }

    @Test("given no codes, should give none")
    func none() {
        #expect(ProductCodes.lines(sku: nil, gtin: nil).isEmpty)
        #expect(ProductCodes.lines(sku: " ", gtin: "").isEmpty)
    }

    @Test("given only a barcode, should give the barcode")
    func barcodeOnly() {
        #expect(ProductCodes.lines(sku: nil, gtin: "3664798067460") == [.barcode("3664798067460")])
    }
}
