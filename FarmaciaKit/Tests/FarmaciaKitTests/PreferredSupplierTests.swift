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

    @Test("given a run supplier and a different preferred supplier, should pick the run supplier")
    func runSupplierWins() {
        #expect(PreferredSupplier.pick(run: .supplier("s1"), preferredId: "s2", selectedId: nil, available: ["s1", "s2"]) == "s1")
    }

    @Test("given a run supplier not in the list yet, should pick nothing, not the preferred one")
    func waitsForRunSupplier() {
        #expect(PreferredSupplier.pick(run: .supplier("s3"), preferredId: "s2", selectedId: nil, available: ["s1", "s2"]) == nil)
    }

    @Test("given the run set to Sin proveedor, should leave the form on none, not the preferred one")
    func runWithoutSupplier() {
        #expect(PreferredSupplier.pick(run: .noSupplier, preferredId: "s2", selectedId: nil, available: ["s1", "s2"]) == nil)
    }

    @Test("given no choice made for the run, should pick the preferred one")
    func runUnset() {
        #expect(PreferredSupplier.pick(run: .unset, preferredId: "s2", selectedId: nil, available: ["s1", "s2"]) == "s2")
    }

    @Test("given the run picker, should read nothing chosen / Sin proveedor / the supplier",
          arguments: [(false, nil as String?, RunSupplier.unset), (true, nil, .noSupplier), (true, "s1", .supplier("s1"))])
    func runFromPicker(chosen: Bool, id: String?, run: RunSupplier) {
        #expect(RunSupplier(chosen: chosen, id: id) == run)
    }
}
