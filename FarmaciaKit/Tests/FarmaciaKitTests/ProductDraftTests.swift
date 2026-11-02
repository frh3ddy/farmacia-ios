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

    @Test("given a switch flipped, a price or a photo, should have changes")
    func nonTextChanges() {
        let start = ProductDraft()
        var stock = start
        stock.hasInitialStock = true
        var price = start
        price.sellingPrice = 25
        var photo = start
        photo.hasPhoto = true
        #expect(stock.hasChanges(from: start))
        #expect(price.hasChanges(from: start))
        #expect(photo.hasChanges(from: start))
    }
}
