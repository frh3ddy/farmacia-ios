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

    @Test("given the owner, should offer applying a price to every store; given a manager, should not",
          arguments: [(true, true), (false, false)])
    func everyStore(isOwner: Bool, expected: Bool) {
        #expect(PriceEditing.canApplyToAllLocations(isOwner: isOwner) == expected)
    }
}
