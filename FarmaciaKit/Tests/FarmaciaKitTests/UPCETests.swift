import Testing
@testable import FarmaciaKit

struct UPCETests {
    @Test("given UPC-E 04252614, should expand to UPC-A 042100005264, which is valid")
    func wikipediaExample() throws {
        let upcA = try #require(UPCE.expanded("04252614"))
        #expect(upcA == "042100005264")
        #expect(GTINCheck.isValid(upcA))
    }

    // GS1 zero-suppression, by the last of the six middle digits; the check digit carries over.
    // These check digits are arbitrary (not valid UPC-As): this tests expansion only.
    @Test("given each zero-suppression form, should expand per GS1", arguments: [
        ("01234505", "012000003455"), // 0–2: manufacturer d1 d2 d6, product d3 d4 d5
        ("01234536", "012300000456"), // 3
        ("01234547", "012340000057"), // 4
        ("01234558", "012345000058"), // 5–9
    ])
    func forms(upcE: String, upcA: String) { #expect(UPCE.expanded(upcE) == upcA) }

    @Test("given a UPC-E with a wrong check digit, its expansion should be invalid")
    func wrongCheck() throws {
        #expect(!GTINCheck.isValid(try #require(UPCE.expanded("04252615"))))
    }

    @Test("given number system 2, a wrong length or non-digits, should not expand",
          arguments: ["24252614", "0425261", "042526145", "0425261A"])
    func notUPCE(code: String) { #expect(UPCE.expanded(code) == nil) }
}
