import Testing
@testable import FarmaciaKit

/// What Apple Intelligence returns can carry quotes, a final period or extra
/// spaces; an empty or rambling answer isn't a name.
struct ModelNameTests {
    @Test("given a quoted answer with a final period, should return the bare name")
    func stripsQuotesAndPeriod() {
        #expect(ModelName.clean("\"Botella verde.\"") == "Botella verde")
    }

    @Test("given Spanish quotes and extra spaces, should tidy them",
          arguments: [("«Oso de peluche  blanco»", "Oso de peluche blanco"), ("  Parches para acné \n", "Parches para acné")])
    func tidies(raw: String, expected: String) {
        #expect(ModelName.clean(raw) == expected)
    }

    @Test("given a blank answer or one longer than 60 characters, should return nil",
          arguments: ["", "  \"\" ", String(repeating: "palabra ", count: 9)])
    func rejects(raw: String) {
        #expect(ModelName.clean(raw) == nil)
    }
}
