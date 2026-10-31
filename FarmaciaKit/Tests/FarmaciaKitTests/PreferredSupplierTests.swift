import Testing
@testable import FarmaciaKit

struct PreferredSupplierTests {
    @Test("given preferred supplier s2 and a loaded supplier list containing s2, should pick s2")
    func picksPreferred() {
        #expect(PreferredSupplier.pick(preferredId: "s2", selectedId: nil, available: ["s1", "s2"]) == "s2")
    }

    @Test("given the supplier list not loaded yet, should not pick (the next load picks)")
    func waitsForList() {
        #expect(PreferredSupplier.pick(preferredId: "s2", selectedId: nil, available: []) == nil)
    }

    @Test("given a supplier the user already chose, should keep it")
    func keepsUserChoice() {
        #expect(PreferredSupplier.pick(preferredId: "s2", selectedId: "s1", available: ["s1", "s2"]) == nil)
    }
}
