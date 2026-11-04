import Testing
@testable import FarmaciaKit

struct MarginPickTests {
    @Test("given 40% picked and the cost changes from 12 to 15, should suggest 25.00")
    func costChanges() {
        let pick = MarginPick(selected: 40)
        #expect(pick.price(forCost: 12) == 20)
        #expect(pick.price(forCost: 15) == 25)
    }

    @Test("given 40% picked and the user types 22, should release the chip")
    func typedOther() {
        var pick = MarginPick(selected: 40)
        pick.priceTyped(22, cost: 12)
        #expect(pick.selected == nil)
    }

    @Test("given the user types exactly the suggested 20.00 at cost 12, should keep 40%")
    func typedSame() {
        var pick = MarginPick(selected: 40)
        pick.priceTyped(20, cost: 12)
        #expect(pick.selected == 40)
    }

    @Test("given no chip picked or no cost, should suggest nothing")
    func nothing() {
        #expect(MarginPick().price(forCost: 12) == nil)
        #expect(MarginPick(selected: 40).price(forCost: nil) == nil)
    }
}
