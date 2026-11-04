import Foundation
import Testing
@testable import FarmaciaKit

/// The receive form can't be swiped away, and Cancelar asks before discarding,
/// once it holds something the user entered. What the form fills in itself (the
/// preferred supplier and its last cost) and values hidden behind a switch that's
/// off (they aren't saved) don't count.
struct ReceivingDraftTests {
    let opened: ReceivingDraft = {
        var draft = ReceivingDraft(expiryDate: Date(timeIntervalSince1970: 1_800_000_000))
        // Filled in by the form when it opened, not by the user.
        draft.supplierId = "sup-preferred"
        draft.unitCost = 12.5
        return draft
    }()

    @Test("given the form as it opened, with the preferred supplier and its cost filled in, should have no changes")
    func asOpened() {
        #expect(!opened.hasChanges(from: opened))
    }

    @Test("given a typed quantity, should have changes")
    func typedQuantity() {
        var draft = opened
        draft.quantity = 10
        #expect(draft.hasChanges(from: opened))
    }

    @Test("given only a box count typed (Cantidad still empty), should have changes")
    func typedBoxesOnly() {
        var draft = opened
        draft.boxes = 3
        #expect(draft.hasChanges(from: opened))
    }

    @Test("given only pieces per box typed, should have changes")
    func typedPerBoxOnly() {
        var draft = opened
        draft.perBox = 12
        #expect(draft.hasChanges(from: opened))
    }

    @Test("given another supplier picked, should have changes")
    func otherSupplier() {
        var draft = opened
        draft.supplierId = "sup-other"
        #expect(draft.hasChanges(from: opened))
    }

    @Test("given the expiry date moved while the expiry switch is off, should have no changes")
    func hiddenExpiry() {
        var draft = opened
        draft.expiryDate = Date(timeIntervalSince1970: 1_900_000_000)
        #expect(!draft.hasChanges(from: opened))
    }

    @Test("given a new price typed and then the update-price switch turned off, should have no changes")
    func hiddenNewPrice() {
        var draft = opened
        draft.updatesPrice = true
        draft.newPrice = 30
        draft.updatesPrice = false
        #expect(!draft.hasChanges(from: opened))
    }

    @Test("given only spaces in the reference numbers or notes, should have no changes")
    func whitespaceOnly() {
        var draft = opened
        draft.invoiceNumber = "  "
        draft.batchNumber = " "
        draft.notes = "\n"
        #expect(!draft.hasChanges(from: opened))
    }
}
