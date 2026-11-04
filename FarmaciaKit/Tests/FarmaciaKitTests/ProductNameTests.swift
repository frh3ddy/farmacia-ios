import Testing
@testable import FarmaciaKit

struct ProductNameTests {
    @Test("given item Buscapina and variation 10 mg 12 tab, should be the full name with the variation")
    func fullWithVariation() {
        #expect(ProductName.full(name: "x", item: "Buscapina", variation: "10 mg 12 tab") == "Buscapina (10 mg 12 tab)")
    }

    @Test("given a placeholder variation, should be the item name alone",
          arguments: ["Regular", " regular ", "Sin variación", "No variation", "Unknown", ""])
    func fullPlaceholder(variation: String) {
        #expect(ProductName.full(name: "x", item: "Buscapina", variation: variation) == "Buscapina")
    }

    @Test("given a variation already in the item name, should not repeat it")
    func fullAlreadyInItem() {
        #expect(ProductName.full(name: "x", item: "Paracetamol 500 mg", variation: "500 MG") == "Paracetamol 500 mg")
    }

    @Test("given no item name, should fall back to the display name")
    func fullNoItem() {
        #expect(ProductName.full(name: "Gasas", item: nil, variation: nil) == "Gasas")
        #expect(ProductName.full(name: "Gasas", item: "  ", variation: "Caja 10") == "Caja 10")
    }

    // Ported Product.displayName rules.

    @Test("given a Square item name, should display it trimmed")
    func displayItem() {
        #expect(ProductName.display(name: "n", item: " Buscapina ", variation: "10 mg") == "Buscapina")
    }

    @Test("given a blank or no-variation item name, should display the variation name",
          arguments: [nil, "", "   ", "Sin variación", "Producto (No Variation)"])
    func displayVariation(item: String?) {
        #expect(ProductName.display(name: "n", item: item, variation: "Caja 10") == "Caja 10")
    }

    @Test("given no usable Square names, should display name")
    func displayName() {
        #expect(ProductName.display(name: "Gasas", item: nil, variation: "Sin variacion") == "Gasas")
    }
}

struct ProductNameLengthTests {
    @Test("given a 27-character name, should show no hint")
    func short() {
        #expect(ProductName.lengthHint(String(repeating: "a", count: 27)) == nil)
    }

    @Test("given 28 to 32 characters, should show a neutral counter",
          arguments: [28, 32])
    func near(count: Int) {
        #expect(ProductName.lengthHint(String(repeating: "a", count: count))
                == .init(text: "\(count)/32", tone: .neutral))
    }

    @Test("given more than 32 characters, should warn that POS and receipts cut it")
    func over() {
        #expect(ProductName.lengthHint(String(repeating: "a", count: 40))
                == .init(text: "40/32 · Square POS y los tickets muestran ~32 caracteres", tone: .caution))
    }

    @Test("given surrounding spaces, should count the trimmed name")
    func trimmed() {
        #expect(ProductName.lengthHint("  " + String(repeating: "a", count: 27) + "  ") == nil)
    }
}
