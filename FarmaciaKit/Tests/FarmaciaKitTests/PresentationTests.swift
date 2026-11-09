import Testing
@testable import FarmaciaKit

/// The presentation read off a photographed label, for an empty Descripción.
struct PresentationTests {
    @Test("given Frasco con 100 ml, should return 100 ml")
    func volume() {
        #expect(Presentation.read(lines: ["Frasco con 100 ml"]) == "100 ml")
    }

    @Test("given one amount or count, should return it normalized",
          arguments: [
            ("Caja con 30 tabletas", "30 tabletas"),
            ("20 cápsulas", "20 cápsulas"),
            ("500 mg", "500 mg"),
            ("Contenido 1 L", "1 L"),
            ("36 PARCHES", "36 parches"),
            ("Contenido neto 250 ML", "250 ml"),
          ])
    func single(line: String, expected: String) {
        #expect(Presentation.read(lines: [line]) == expected)
    }

    @Test("given an amount and a count, should return both")
    func amountAndCount() {
        #expect(Presentation.read(lines: ["IBUPROFENO", "500 mg", "Caja con 30 tabletas"]) == "500 mg · 30 tabletas")
    }

    @Test("given a Mexican count abbreviation, should spell it out",
          arguments: [
            ("c/20 TABS", "20 tabletas"),
            ("30 tab", "30 tabletas"),
            ("12 caps", "12 cápsulas"),
            ("40 pz", "40 piezas"),
            ("C/10 PZAS", "10 piezas"),
          ])
    func abbreviation(line: String, expected: String) {
        #expect(Presentation.read(lines: [line]) == expected)
    }

    @Test("given an amount and an abbreviated count on one line, should return both")
    func amountAndAbbreviation() {
        #expect(Presentation.read(lines: ["500 mg c/20 TABS"]) == "500 mg · 20 tabletas")
    }

    @Test("given only a date, lot and registration, should return nil")
    func noPresentation() {
        #expect(Presentation.read(lines: ["Lote 2501", "Cad 12/27", "Reg. San. 123M2015 SSA"]) == nil)
    }
}
