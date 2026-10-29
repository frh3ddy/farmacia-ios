import Testing
@testable import FarmaciaKit

struct BatchSourceTests {
    @Test("given a batch source from the API, should show its Spanish label",
          arguments: [("OPENING_BALANCE", "Saldo Inicial"), ("PURCHASE", "Compra"), ("ADJUSTMENT", "Ajuste")])
    func known(source: String, expected: String) {
        #expect(BatchSource.label(source) == expected)
    }

    @Test("given no source, should say 'Desconocido'")
    func missing() {
        #expect(BatchSource.label(nil) == "Desconocido")
    }

    @Test("given a source the app doesn't know, should show it as-is")
    func unknown() {
        #expect(BatchSource.label("TRANSFER") == "TRANSFER")
    }
}
