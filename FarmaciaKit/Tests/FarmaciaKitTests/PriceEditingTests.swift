import Testing
@testable import FarmaciaKit

struct PriceEditingTests {
    @Test("given an owner or a manager on a product with stock tracking, should allow editing its price",
          arguments: [(true, false), (false, true)])
    func canEdit(isOwner: Bool, isManager: Bool) {
        #expect(PriceEditing.canEdit(isOwner: isOwner, isManager: isManager, tracksInventory: true))
    }

    @Test("given a cashier, should not allow editing a price")
    func cashier() {
        #expect(!PriceEditing.canEdit(isOwner: false, isManager: false, tracksInventory: true))
    }

    @Test("given a Yastás product (no stock tracking, no set price), should not allow editing its price, even for the owner")
    func yastas() {
        #expect(!PriceEditing.canEdit(isOwner: true, isManager: false, tracksInventory: false))
    }

    @Test("given a product whose stock tracking is unknown (an older cached copy), should allow editing as a normal product")
    func unknownTracking() {
        #expect(PriceEditing.canEdit(isOwner: false, isManager: true, tracksInventory: nil))
    }
}

/// Editar Precio's Guardar: a positive price that differs from the current one.
struct PriceEditingSaveTests {
    @Test("given the current price typed again, should not save")
    func unchanged() {
        #expect(!PriceEditing.canSave(newPrice: 25, currentPrice: 25))
    }

    @Test("given a new positive price, should save")
    func changed() {
        #expect(PriceEditing.canSave(newPrice: 27.5, currentPrice: 25))
    }

    @Test("given 0 or no price, should not save")
    func missing() {
        #expect(!PriceEditing.canSave(newPrice: 0, currentPrice: 25))
        #expect(!PriceEditing.canSave(newPrice: nil, currentPrice: 25))
    }

    @Test("given a product without a price yet, should save a first price")
    func firstPrice() {
        #expect(PriceEditing.canSave(newPrice: 25, currentPrice: nil))
    }
}

struct PriceScopeTests {
    @Test("given the owner and a product sold at every store, should apply to every store")
    func ownerEverywhere() {
        #expect(PriceEditing.appliesToAllLocations(isOwner: true, soldOnlyAtLocationId: nil))
    }

    @Test("given a manager, or a product sold at only one store, should apply to one store only",
          arguments: [(false, nil), (true, "loc-1")] as [(Bool, String?)])
    func oneStore(isOwner: Bool, soldOnlyAt: String?) {
        #expect(!PriceEditing.appliesToAllLocations(isOwner: isOwner, soldOnlyAtLocationId: soldOnlyAt))
    }
}

struct PriceScopeNoteTests {
    @Test("given all stores with Square on, should say every store and Square POS")
    func everywhere() {
        #expect(PriceEditing.scopeNote(allLocations: true, syncToSquare: true, inSquare: true, storeName: "Centro", isOwner: true)
                == "Se aplica en todas las sucursales y en Square POS.")
    }

    @Test("given one store, should name it")
    func oneStore() {
        #expect(PriceEditing.scopeNote(allLocations: false, syncToSquare: true, inSquare: true, storeName: "Centro", isOwner: true)
                == "Solo cambia en Centro y en su Square POS.")
    }

    @Test("given a manager, should say only their store, and that the owner changes the others")
    func manager() {
        #expect(PriceEditing.scopeNote(allLocations: false, syncToSquare: true, inSquare: true, storeName: "Centro", isOwner: false)
                == "Solo cambia en Centro y en su Square POS. El precio de las demás sucursales lo cambia el dueño.")
    }

    @Test("given Square off, should say Square POS keeps the old price")
    func squareOff() {
        #expect(PriceEditing.scopeNote(allLocations: true, syncToSquare: false, inSquare: true, storeName: "Centro", isOwner: true)
                == "Se aplica en todas las sucursales; Square POS sigue mostrando el precio anterior.")
    }

    @Test("given a product that isn't in Square, should not mention Square POS",
          arguments: [true, false])
    func notInSquare(syncToSquare: Bool) {
        #expect(PriceEditing.scopeNote(allLocations: true, syncToSquare: syncToSquare, inSquare: false,
                                       storeName: "Centro", isOwner: true)
                == "Se aplica en todas las sucursales.")
        #expect(PriceEditing.scopeNote(allLocations: false, syncToSquare: syncToSquare, inSquare: false,
                                       storeName: "Centro", isOwner: false)
                == "Solo cambia en Centro. El precio de las demás sucursales lo cambia el dueño.")
    }
}
