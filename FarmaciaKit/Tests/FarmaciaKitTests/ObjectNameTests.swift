import Testing
@testable import FarmaciaKit

/// When the label has no readable name: Vision's object labels (real
/// VNClassifyImageRequest identifiers, best first) plus the object's color,
/// in Spanish with gender agreement.
struct ObjectNameTests {
    let green = ColorName(masculine: "verde", feminine: "verde")
    let white = ColorName(masculine: "blanco", feminine: "blanca")

    @Test("given label bottle and green, should return Botella verde")
    func greenBottle() {
        #expect(ObjectName.spanish(labels: ["bottle"], color: green) == "Botella verde")
    }

    @Test("given labels outside pharmacy stock before a known one, should name the known one")
    func skipsNonStock() {
        #expect(ObjectName.spanish(labels: ["bear", "toy"], color: white) == "Juguete blanco")
    }

    @Test("given a pharmacy item, should name it in Spanish",
          arguments: [("glove", "Guante blanco"), ("chewing_gum", "Chicle blanco"),
                      ("sunglasses", "Lentes de sol blancos"), ("drink", "Bebida blanca"),
                      ("lollipop", "Paleta blanca"), ("figurine", "Figura blanca"),
                      ("jewelry", "Bisutería blanca"), ("pen", "Pluma blanca"),
                      ("play_card", "Baraja blanca"), ("piggybank", "Alcancía blanca")])
    func pharmacyStock(label: String, expected: String) {
        #expect(ObjectName.spanish(labels: [label], color: white) == expected)
    }

    @Test("given a plush with an animal label, should name it Peluche")
    func plush() {
        #expect(ObjectName.spanish(labels: ["lion", "stuffed_animals", "toy"], color: white) == "Peluche blanco")
    }

    @Test("given bottle and white, should agree in the feminine")
    func feminine() {
        #expect(ObjectName.spanish(labels: ["bottle"], color: white) == "Botella blanca")
    }

    @Test("given a generic label before a specific one, should name the specific one")
    func specificWins() {
        #expect(ObjectName.spanish(labels: ["container", "jar"], color: white) == "Frasco blanco")
    }

    @Test("given only a generic label, should still name it")
    func genericAlone() {
        #expect(ObjectName.spanish(labels: ["toy"], color: green) == "Juguete verde")
    }

    @Test("given no color, should return the noun alone")
    func noColor() {
        #expect(ObjectName.spanish(labels: ["bottle"], color: nil) == "Botella")
    }

    @Test("given only labels not in the table, should return nil")
    func unknown() {
        #expect(ObjectName.spanish(labels: ["canyon", "waterfall"], color: green) == nil)
    }
}
