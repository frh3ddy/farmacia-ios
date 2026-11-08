import Testing
@testable import FarmaciaKit

struct StoreTintTests {
    // Pinned to 64-bit FNV-1a: a seeded hash (Hasher/hashValue) would change the color every launch.
    @Test("given location id loc-centro and a palette of 6, should return the pinned index 3")
    func pinnedIndex() {
        #expect(StoreTint.paletteIndex(forLocationId: "loc-centro", paletteCount: 6) == 3)
    }

    // The production stores (2026-11-07). If a change to the hash or palette makes them share a color, this fails.
    @Test("given the production store ids, should give Farmacia Lolita and Oriente different colors")
    func productionStoresDistinct() {
        let lolita = StoreTint.paletteIndex(forLocationId: "f1931c0e-f2ad-484d-9b0a-57e8cd069ef0", paletteCount: 6)
        let oriente = StoreTint.paletteIndex(forLocationId: "4b9f86a3-fe45-439a-bd21-f3dfd913f744", paletteCount: 6)
        #expect(lolita == 4)
        #expect(oriente == 3)
    }

    @Test("given any id, including empty, should return an index inside the palette",
          arguments: ["", "a", "cm9x2k1q0000abcd", "Sucursal Prueba ñ"])
    func inRange(id: String) {
        #expect((0..<6).contains(StoreTint.paletteIndex(forLocationId: id, paletteCount: 6)))
    }

    @Test("given 1 store, should not show the strip")
    func oneStore() {
        #expect(StoreTint.showsStrip(storeCount: 1) == false)
    }

    @Test("given 2 stores, should show the strip")
    func twoStores() {
        #expect(StoreTint.showsStrip(storeCount: 2))
    }
}
