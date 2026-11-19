import Testing
@testable import FarmaciaKit

struct PhotoSearchSinCodigoTests {
    @Test("given an empty gtin and a SKU like PARA-500, should be sin código")
    func internalSku() {
        #expect(PhotoSearch.isSinCodigo(sku: "PARA-500", gtin: nil, tracksInventory: true))
    }

    @Test("given a barcode-shaped SKU (EAN-13, UPC-A, EAN-8, GTIN-14), should not be sin código",
          arguments: ["7501234567890", "012345678905", "12345670", "17501234567897"])
    func barcodeSku(sku: String) {
        #expect(!PhotoSearch.isSinCodigo(sku: sku, gtin: nil, tracksInventory: true))
    }

    @Test("given a gtin, should not be sin código")
    func hasGtin() {
        #expect(!PhotoSearch.isSinCodigo(sku: "PARA-500", gtin: "7501234567890", tracksInventory: true))
    }

    @Test("given a whitespace-only gtin, should be sin código")
    func blankGtin() {
        #expect(PhotoSearch.isSinCodigo(sku: "PARA-500", gtin: "  ", tracksInventory: true))
    }

    @Test("given a barcode-shaped SKU with stray spaces, should not be sin código")
    func paddedBarcodeSku() {
        #expect(!PhotoSearch.isSinCodigo(sku: " 7501234567890 ", gtin: nil, tracksInventory: true))
    }

    @Test("given an item that doesn't track inventory (Yastás service), should not be sin código")
    func service() {
        #expect(!PhotoSearch.isSinCodigo(sku: "YASTAS-TAE", gtin: nil, tracksInventory: false))
    }

    @Test("given an unknown tracksInventory (older server), should count as a physical product")
    func unknownTracking() {
        #expect(PhotoSearch.isSinCodigo(sku: "PARA-500", gtin: nil, tracksInventory: nil))
    }

    @Test("given no SKU and no gtin, should be sin código")
    func nothing() {
        #expect(PhotoSearch.isSinCodigo(sku: nil, gtin: nil, tracksInventory: true))
    }
}
