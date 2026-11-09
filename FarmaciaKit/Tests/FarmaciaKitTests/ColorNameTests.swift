import Testing
@testable import FarmaciaKit

/// The object's color in Spanish, with both genders so "Botella blanca" and
/// "Oso de peluche blanco" agree.
struct ColorNameTests {
    @Test("given (0.1, 0.6, 0.2), should be verde")
    func green() {
        #expect(ColorName.spanish(red: 0.1, green: 0.6, blue: 0.2) == ColorName(masculine: "verde", feminine: "verde"))
    }

    @Test("given an RGB color, should name it in both genders",
          arguments: [
            (0.95, 0.95, 0.93, "blanco", "blanca"),
            (0.08, 0.08, 0.10, "negro", "negra"),
            (0.50, 0.50, 0.52, "gris", "gris"),
            (0.85, 0.10, 0.10, "rojo", "roja"),
            (0.10, 0.30, 0.85, "azul", "azul"),
            (0.95, 0.85, 0.10, "amarillo", "amarilla"),
            (0.95, 0.50, 0.75, "rosa", "rosa"),
            (0.50, 0.20, 0.70, "morado", "morada"),
            (0.45, 0.28, 0.12, "café", "café"),
            (0.95, 0.55, 0.10, "naranja", "naranja"),
          ])
    func named(r: Double, g: Double, b: Double, masculine: String, feminine: String) {
        #expect(ColorName.spanish(red: r, green: g, blue: b) == ColorName(masculine: masculine, feminine: feminine))
    }
}
