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

struct PhotoSearchTextScoreTests {
    @Test("given OCR PARACETAMOL and name Paracetamol, should score above 0")
    func caseInsensitive() {
        #expect(PhotoSearch.textScore(lines: ["PARACETAMOL"], name: "Paracetamol") > 0)
    }

    @Test("given OCR Jabón Neutro and name jabon neutro, should be a full match")
    func accents() {
        #expect(PhotoSearch.textScore(lines: ["Jabón Neutro"], name: "jabon neutro") == 1)
    }

    @Test("given an accent on a short word (Té vs te), should match exactly")
    func shortAccent() {
        #expect(PhotoSearch.textScore(lines: ["TÉ VERDE"], name: "te verde") == 1)
    }

    @Test("given a 5+ digit number one digit off (50000 vs 60000), should not count it")
    func digitsExact() {
        #expect(PhotoSearch.textScore(lines: ["Vitamina D 50000 UI"], name: "Vitamina D 60000 UI") == 0.75)
    }

    @Test("given no lines, should be 0")
    func noLines() {
        #expect(PhotoSearch.textScore(lines: [], name: "Paracetamol 500 mg") == 0)
    }

    @Test("given 500 mg on the box, should score Paracetamol 500 mg above Paracetamol 750 mg")
    func strength() {
        let lines = ["PARACETAMOL", "Tabletas 500 mg"]
        #expect(PhotoSearch.textScore(lines: lines, name: "Paracetamol 500 mg")
                > PhotoSearch.textScore(lines: lines, name: "Paracetamol 750 mg"))
    }

    @Test("given 500mg printed without a space, should still match the name's 500 mg")
    func gluedUnit() {
        #expect(PhotoSearch.textScore(lines: ["Paracetamol 500mg"], name: "Paracetamol 500 mg") == 1)
    }

    @Test("given a one-letter OCR slip in a long word (swapped, dropped or extra letter), should still count the word",
          arguments: ["PARACETAMOI", "PARACETMOL", "PARACETAMOOL"])
    func ocrSlip(read: String) {
        #expect(PhotoSearch.textScore(lines: [read], name: "Paracetamol") == 1)
    }

    @Test("given two slips in a long word (PARACETMOI), should not count it")
    func twoSlips() {
        #expect(PhotoSearch.textScore(lines: ["PARACETMOI"], name: "Paracetamol") == 0)
    }

    @Test("given a one-letter difference in a short word (gel vs sel), should not count it")
    func shortWordsExact() {
        #expect(PhotoSearch.textScore(lines: ["SEL"], name: "Gel") == 0)
    }

    @Test("given only lot and expiry lines, should be 0")
    func noise() {
        #expect(PhotoSearch.textScore(lines: ["LOTE A1234", "CAD 12/2027"], name: "Jabón neutro") == 0)
    }

    @Test("given half the name's words on the box, should score 0.5")
    func partial() {
        #expect(PhotoSearch.textScore(lines: ["NEUTRO"], name: "Jabón neutro") == 0.5)
    }
}
