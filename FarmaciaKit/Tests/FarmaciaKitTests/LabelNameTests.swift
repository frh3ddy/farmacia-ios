import Testing
@testable import FarmaciaKit

/// The product name printed on the label: the biggest text that isn't a lot,
/// date, code, bare amount, registration or web address.
struct LabelNameTests {
    @Test("given ACNE PATCH as the tallest line and the lot and date below, should return Acne Patch")
    func tallestLine() {
        let lines = [
            LabelLine(text: "ACNE PATCH", height: 0.12),
            LabelLine(text: "Lote 2501 / Cad 12/27", height: 0.03),
        ]
        #expect(LabelName.pick(lines: lines) == "Acne Patch")
    }

    @Test("given a tallest line that's noise, should skip it",
          arguments: ["LOTE 2501A", "7501008496725", "500 mg", "Reg. San. 123M2015 SSA", "www.genfar.com", "CAD 12/2027"])
    func skipsNoise(noise: String) {
        let lines = [LabelLine(text: noise, height: 0.2), LabelLine(text: "Ibuprofeno", height: 0.1)]
        #expect(LabelName.pick(lines: lines) == "Ibuprofeno")
    }

    @Test("given two tall lines of similar height, should join them as brand and product")
    func joinsBrandAndProduct() {
        let lines = [
            LabelLine(text: "GENFAR", height: 0.10),
            LabelLine(text: "IBUPROFENO", height: 0.095),
            LabelLine(text: "Tabletas 400 mg", height: 0.04),
        ]
        #expect(LabelName.pick(lines: lines) == "Genfar Ibuprofeno")
    }

    @Test("given a product name starting with Reg, should keep it",
          arguments: ["REGAINE", "Regenerador capilar", "REGULAX"])
    func regNamesKept(name: String) {
        #expect(LabelName.pick(lines: [LabelLine(text: name, height: 0.1)]) != nil)
    }

    @Test("given a big promo word above the name, should skip it",
          arguments: ["NUEVO", "¡OFERTA!", "GRATIS", "PROMOCIÓN", "Contenido neto 250 ml"])
    func skipsPromo(promo: String) {
        let lines = [LabelLine(text: promo, height: 0.2), LabelLine(text: "Ibuprofeno", height: 0.1)]
        #expect(LabelName.pick(lines: lines) == "Ibuprofeno")
    }

    @Test("given a promo word on the name's own line, should drop the word and keep the name")
    func promoInsideName() {
        #expect(LabelName.pick(lines: [LabelLine(text: "NUEVO IBUPROFENO", height: 0.1)]) == "Ibuprofeno")
    }

    @Test("given a name that only contains a promo word, should keep it whole")
    func promoInsideWord() {
        #expect(LabelName.pick(lines: [LabelLine(text: "RENUEVO", height: 0.1)]) == "Renuevo")
    }

    @Test("given an all-caps name with a dose, should keep the unit lowercase")
    func keepsUnitLowercase() {
        #expect(LabelName.pick(lines: [LabelLine(text: "IBUPROFENO 400MG", height: 0.1)]) == "Ibuprofeno 400mg")
    }

    @Test("given mixed-case text, should keep its casing")
    func keepsMixedCase() {
        #expect(LabelName.pick(lines: [LabelLine(text: "Vick VapoRub", height: 0.1)]) == "Vick VapoRub")
    }

    @Test("given no line with at least 3 letters, should return nil")
    func nothingReadable() {
        #expect(LabelName.pick(lines: [LabelLine(text: "12", height: 0.2), LabelLine(text: "A1", height: 0.1)]) == nil)
    }
}
