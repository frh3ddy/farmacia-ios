import Foundation
import Testing
@testable import FarmaciaKit

/// The new-product form can't be swiped away, and Cancelar asks before
/// discarding, once it holds something the user entered. What the form started
/// with (a SKU from the barcode scanner, the default switches) isn't a change.
struct ProductDraftTests {
    @Test("given a fresh form with only a scanned SKU, should have no changes")
    func scannedSkuOnly() {
        let start = ProductDraft(prefillSku: "7501008496725")
        #expect(!start.hasChanges(from: start))
    }

    @Test("given a typed name, should have changes")
    func typedName() {
        let start = ProductDraft()
        var draft = start
        draft.name = "Paracetamol 500mg"
        #expect(draft.hasChanges(from: start))
    }

    @Test("given only spaces typed, should have no changes")
    func whitespaceOnly() {
        let start = ProductDraft()
        var draft = start
        draft.name = "  "
        draft.description = "\n"
        #expect(!draft.hasChanges(from: start))
    }

    @Test("given a name typed and then cleared, should have no changes")
    func undone() {
        let start = ProductDraft(prefillSku: "123")
        var draft = start
        draft.name = "Algo"
        draft.name = ""
        #expect(!draft.hasChanges(from: start))
    }

    @Test("given a scanned SKU, should keep Más detalles closed (the SKU shows with the essentials)")
    func scannedSkuKeepsDetailsClosed() {
        #expect(!ProductDraft(prefillSku: "7501008496725").hasDetails)
    }

    @Test("given a description, should open Más detalles")
    func descriptionOpensDetails() {
        var draft = ProductDraft()
        draft.description = "Caja con 20 tabletas"
        #expect(draft.hasDetails)
    }

    @Test("given a fresh form, should keep Más detalles closed")
    func freshKeepsDetailsClosed() {
        #expect(!ProductDraft().hasDetails)
    }

    @Test("given Square sync or all-stores switched off, should open Más detalles")
    func settingsOpenDetails() {
        var square = ProductDraft()
        square.syncToSquare = false
        var stores = ProductDraft()
        stores.soldAtAllLocations = false
        #expect(square.hasDetails)
        #expect(stores.hasDetails)
    }

    @Test("given a quantity, a price or a photo, should have changes")
    func nonTextChanges() {
        let start = ProductDraft()
        var stock = start
        stock.initialStock = 5
        var price = start
        price.sellingPrice = 25
        var photo = start
        photo.hasPhoto = true
        #expect(stock.hasChanges(from: start))
        #expect(price.hasChanges(from: start))
        #expect(photo.hasChanges(from: start))
    }
}

/// Crear is allowed with a name and a price. Initial stock has no switch: the
/// stock fields are always shown, and a quantity is what creates it — then its
/// cost is required. A cost without a quantity blocks saving rather than being
/// dropped silently.
struct ProductDraftSaveTests {
    let named: ProductDraft = {
        var draft = ProductDraft()
        draft.name = "Paracetamol 500mg"
        draft.sellingPrice = 25
        return draft
    }()

    @Test("given a name and a price without a quantity, should save without initial stock")
    func noStock() {
        #expect(named.canSave)
        #expect(!named.createsInitialStock)
    }

    @Test("given a quantity and a cost, should save with initial stock")
    func withStock() {
        var draft = named
        draft.initialStock = 10
        draft.costPrice = 12
        #expect(draft.canSave)
        #expect(draft.createsInitialStock)
    }

    @Test("given a quantity without a cost, should not save")
    func quantityWithoutCost() {
        var draft = named
        draft.initialStock = 10
        #expect(!draft.canSave)
    }

    @Test("given a cost without a quantity, should not save")
    func costWithoutQuantity() {
        var draft = named
        draft.costPrice = 12
        #expect(!draft.canSave)
    }

    @Test("given a quantity with a cost of 0 (e.g. a free sample), should save")
    func zeroCost() {
        var draft = named
        draft.initialStock = 3
        draft.costPrice = 0
        #expect(draft.canSave)
    }

    @Test("given no name, or a price of 0, should not save")
    func missingEssentials() {
        var noName = named
        noName.name = "  "
        var freePrice = named
        freePrice.sellingPrice = 0
        #expect(!noName.canSave)
        #expect(!freePrice.canSave)
    }
}
