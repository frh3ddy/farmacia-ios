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

struct FeatureVectorTests {
    @Test("given two identical vectors, should be 1")
    func identical() {
        #expect(FeatureVector.similarity([0.6, 0.8], [0.6, 0.8]) == 1)
    }

    @Test("given orthogonal vectors, should be 0")
    func orthogonal() {
        #expect(FeatureVector.similarity([1, 0], [0, 1]) == 0)
    }

    @Test("given the same direction at another length, should be 1 (only direction counts)")
    func scaled() throws {
        let s = try #require(FeatureVector.similarity([3, 4], [0.6, 0.8]))
        #expect(abs(s - 1) < 1e-9)
    }

    @Test("given different lengths (another Vision revision), should be nil")
    func lengths() {
        #expect(FeatureVector.similarity([1, 0], [1, 0, 0]) == nil)
    }

    @Test("given an all-zero vector, should be nil, not NaN")
    func zero() {
        #expect(FeatureVector.similarity([0, 0], [1, 0]) == nil)
    }

    @Test("given empty vectors, should be nil")
    func empty() {
        #expect(FeatureVector.similarity([], []) == nil)
    }
}

struct PhotoSearchRankTests {
    typealias C = PhotoSearch.Candidate

    /// A unit vector whose cosine with `photo` ([1, 0]) is `cos`. Real feature prints
    /// (Vision revision 2, measured on the user's photos): the same box ≈ 0.8,
    /// unrelated products 0.2–0.58, mostly 0.3–0.45. Never 0.
    static func look(_ cos: Float) -> [Float] { [cos, (1 - cos * cos).squareRoot()] }
    static let photo: [Float] = [1, 0]

    @Test("given no text and no photo vector, should return every candidate in name order")
    func fallback() {
        let ranked = PhotoSearch.rank([C(id: "b", name: "Venda"), C(id: "a", name: "Algodón"), C(id: "c", name: "jabón")],
                                      lines: [], photo: nil)
        #expect(ranked.map(\.id) == ["a", "c", "b"])
    }

    @Test("given one name word read on a product with no photo, an unrelated-looking product (cos 0.45) should not outrank it")
    func unrelatedLookIsNotAHeadStart() {
        let ranked = PhotoSearch.rank([C(id: "unrelated", name: "Venda elástica", vector: Self.look(0.45)),
                                       C(id: "read", name: "Jabón neutro líquido 500 ml", vector: nil)],
                                      lines: ["NEUTRO"], photo: Self.photo)
        #expect(ranked.first?.id == "read")
    }

    @Test("given an unrelated look (cos 0.35) and no photo at all, should tie and fall back to name order")
    func unrelatedLookAddsNothing() {
        let ranked = PhotoSearch.rank([C(id: "unrelated", name: "Venda", vector: Self.look(0.35)),
                                       C(id: "none", name: "Algodón", vector: nil)],
                                      lines: [], photo: Self.photo)
        #expect(ranked.map(\.id) == ["none", "unrelated"])
    }

    @Test("given 500 mg on the box, the 500 mg product should beat a 750 mg one that looks more alike")
    func strengthBeatsLook() {
        let ranked = PhotoSearch.rank([C(id: "750", name: "Paracetamol 750 mg", vector: Self.look(0.85)),
                                       C(id: "500", name: "Paracetamol 500 mg", vector: Self.look(0.75))],
                                      lines: ["PARACETAMOL 500 mg"], photo: Self.photo)
        #expect(ranked.first?.id == "500")
    }

    @Test("given a strong text match on a product with no reference photo, it should beat the same-looking box")
    func textWithoutPhoto() {
        let ranked = PhotoSearch.rank([C(id: "look", name: "Venda elástica", vector: Self.look(0.8)),
                                       C(id: "text", name: "Jabón neutro", vector: nil)],
                                      lines: ["JABÓN NEUTRO"], photo: Self.photo)
        #expect(ranked.first?.id == "text")
    }

    @Test("given no text, the same box (cos 0.8) should come before an unrelated one (cos 0.35)")
    func lookBreaksTie() {
        let ranked = PhotoSearch.rank([C(id: "far", name: "Chupón", vector: Self.look(0.35)),
                                       C(id: "near", name: "Mordedera", vector: Self.look(0.8))],
                                      lines: [], photo: Self.photo)
        #expect(ranked.map(\.id) == ["near", "far"])
    }

    @Test("given a blue and a pink variant and a photo closest to blue, blue first and pink right behind")
    func colorVariants() {
        let ranked = PhotoSearch.rank([C(id: "other", name: "Algodón", vector: Self.look(0.35)),
                                       C(id: "pink", name: "Chupón rosa", vector: Self.look(0.75)),
                                       C(id: "blue", name: "Chupón azul", vector: Self.look(0.85))],
                                      lines: [], photo: Self.photo)
        #expect(ranked.map(\.id) == ["blue", "pink", "other"])
    }

    @Test("given a reference vector from another Vision revision (other length), should rank on text only, not crash")
    func otherRevision() {
        let ranked = PhotoSearch.rank([C(id: "old", name: "Venda", vector: [1, 0, 0]),
                                       C(id: "ok", name: "Algodón", vector: Self.look(0.8))],
                                      lines: [], photo: Self.photo)
        #expect(ranked.map(\.id) == ["ok", "old"])
    }

    @Test("given an opposite-looking product, its image score should not push it below one with no photo")
    func negativeSimilarity() {
        let ranked = PhotoSearch.rank([C(id: "opposite", name: "Algodón", vector: [-1, 0]),
                                       C(id: "none", name: "Venda", vector: nil)],
                                      lines: [], photo: Self.photo)
        #expect(ranked.map(\.id) == ["opposite", "none"])
    }
}

struct PhotoSearchWeightsTests {
    typealias C = PhotoSearch.Candidate

    @Test("given weights with no image share, looks should not change the order")
    func imageOff() {
        let ranked = PhotoSearch.rank([C(id: "b", name: "Mordedera", vector: PhotoSearchRankTests.look(0.95)),
                                       C(id: "a", name: "Chupón", vector: PhotoSearchRankTests.look(0.35))],
                                      lines: [], photo: PhotoSearchRankTests.photo,
                                      weights: .init(text: 1, image: 0, unrelatedFloor: 0.5))
        #expect(ranked.map(\.id) == ["a", "b"])
    }

    @Test("given a lower floor, a 0.45 look should count")
    func lowerFloor() {
        let ranked = PhotoSearch.rank([C(id: "a", name: "Chupón", vector: nil),
                                       C(id: "b", name: "Mordedera", vector: PhotoSearchRankTests.look(0.45))],
                                      lines: [], photo: PhotoSearchRankTests.photo,
                                      weights: .init(text: 0.6, image: 0.4, unrelatedFloor: 0.3))
        #expect(ranked.map(\.id) == ["b", "a"])
    }
}

struct PhotoBenchTests {
    typealias R = PhotoBench.Result

    @Test("given the expected product third, should miss top 1 and hit top 5")
    func topK() {
        let results = [R(expected: "c", ranked: ["a", "b", "c", "d"])]
        #expect(PhotoBench.hitRate(results, top: 1) == 0)
        #expect(PhotoBench.hitRate(results, top: 5) == 1)
    }

    @Test("given one hit in two queries, should be 0.5")
    func rate() {
        let results = [R(expected: "a", ranked: ["a", "b"]), R(expected: "z", ranked: ["a", "b"])]
        #expect(PhotoBench.hitRate(results, top: 1) == 0.5)
    }

    @Test("given no queries, should be 0")
    func empty() {
        #expect(PhotoBench.hitRate([], top: 5) == 0)
    }

    @Test("given a reference filename, should use its name as the product", arguments: [
        ("Jabón neutro.jpg", "Jabón neutro"), ("Chupón azul.HEIC", "Chupón azul"),
    ])
    func referenceName(file: String, name: String) {
        #expect(PhotoBench.referenceName(fromFilename: file) == name)
    }

    @Test("given a query filename, should take the product after the last underscore", arguments: [
        ("IMG_5770_Jabón neutro.HEIC", "Jabón neutro"), ("counter_Chupón azul.jpg", "Chupón azul"),
    ])
    func queryExpected(file: String, name: String?) {
        #expect(PhotoBench.expected(fromFilename: file) == name)
    }

    @Test("given a query filename with no underscore, should be nil")
    func noExpected() {
        #expect(PhotoBench.expected(fromFilename: "IMG5770.HEIC") == nil)
    }
}
