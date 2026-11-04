import Foundation
import Testing
@testable import FarmaciaKit

/// The new-product form can't be swiped away, and Cancelar asks before
/// discarding, once it holds something the user entered. What the form started
/// with (a SKU from the barcode scanner, the default switches) isn't a change.
struct ProductDraftTests {
    @Test("given a fresh form with only a scanned barcode, should have no changes")
    func scannedSkuOnly() {
        let start = ProductDraft(prefillBarcode: "7501008496725")
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
        let start = ProductDraft(prefillBarcode: "123")
        var draft = start
        draft.name = "Algo"
        draft.name = ""
        #expect(!draft.hasChanges(from: start))
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
/// cost is required. A cost without a quantity is fine: it drives the
/// suggested price and isn't sent.
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

    @Test("given a cost without a quantity, should save without initial stock (the cost drives the suggested price)")
    func costWithoutQuantity() {
        var draft = named
        draft.costPrice = 12
        #expect(draft.canSave)
        #expect(!draft.createsInitialStock)
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

/// Why Crear can't save, said next to the field that fixes it after the first tap,
/// in form order (the first one gets focus).
struct ProductDraftIssueTests {
    func draft(price: Double? = 10, cost: Double? = nil, stock: Int? = nil) -> ProductDraft {
        var d = ProductDraft()
        d.name = "Paracetamol"
        d.sellingPrice = price
        d.costPrice = cost
        d.initialStock = stock
        return d
    }

    @Test("given a cost and no quantity, should have no issues")
    func costWithoutQuantity() {
        #expect(draft(cost: 5).issues.isEmpty)
    }

    @Test("given an empty form, should list the name then the price")
    func emptyForm() {
        #expect(ProductDraft().issues == [.nameMissing, .priceMissing])
    }

    @Test("given every problem at once, should list them in form order: name, cost, price, barcode")
    func formOrder() {
        var d = ProductDraft(prefillBarcode: "12345")
        d.sellingPrice = 0
        d.initialStock = 2
        #expect(d.issues == [.nameMissing, .costNeeded, .priceNotPositive, .barcodeInvalid])
    }

    @Test("given a quantity and no cost, should ask for the cost")
    func quantityWithoutCost() {
        #expect(draft(stock: 3).issues == [.costNeeded])
    }

    @Test("given a price of 0, should say it must be above 0")
    func zeroPrice() {
        #expect(draft(price: 0).issues == [.priceNotPositive])
    }

    @Test("given an empty price, should ask for it (errors show only after the first tap)")
    func emptyPrice() {
        #expect(draft(price: nil).issues == [.priceMissing])
    }

    @Test("given a valid draft, should have no issues and be saveable")
    func valid() {
        let d = draft(cost: 5, stock: 3)
        #expect(d.issues.isEmpty)
        #expect(d.canSave)
    }

    @Test("each issue should explain the fix in Spanish")
    func messages() {
        #expect(ProductDraft.Issue.nameMissing.message == "Escribe el nombre del producto.")
        #expect(ProductDraft.Issue.priceMissing.message == "Indica el precio de venta.")
        #expect(ProductDraft.Issue.costNeeded.message == "Indica el costo por unidad del inventario inicial (0 si fue regalo).")
        #expect(ProductDraft.Issue.priceNotPositive.message == "El precio debe ser mayor a $0.")
    }

    @Test("given a scan, should fill the barcode and leave the SKU empty (the server makes one)")
    func scanFillsBarcode() {
        let draft = ProductDraft(prefillBarcode: "3664798067460")
        #expect(draft.gtin == "3664798067460" && draft.sku.isEmpty)
    }

    @Test("given a barcode that isn't 8, 12, 13 or 14 digits, Crear should be off and say why",
          arguments: ["12345", "36647980674", "366479806746A", "036647980674601"])
    func invalidBarcode(gtin: String) {
        var draft = ProductDraft(prefillBarcode: gtin)
        draft.name = "Buscapina"
        draft.sellingPrice = 220
        #expect(!draft.canSave)
        #expect(draft.issues == [.barcodeInvalid])
    }

    @Test("given a valid barcode, or none, Crear should be on", arguments: ["", "  ", "96385074", "012345678905", "3664798067460", "03664798067460", " 3664798067460 "])
    func validBarcode(gtin: String) {
        var draft = ProductDraft(prefillBarcode: gtin)
        draft.name = "Buscapina"
        draft.sellingPrice = 220
        #expect(draft.canSave)
        #expect(draft.issues.isEmpty)
    }
}
