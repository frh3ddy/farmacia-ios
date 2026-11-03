import Testing
@testable import FarmaciaKit

/// Receiving by the box: Cajas × Piezas por caja fills Cantidad, so nobody multiplies in their head.
struct PackQuantityTests {
    @Test("given 3 boxes of 12, should be 36")
    func boxes() { #expect(PackQuantity.total(boxes: 3, perBox: 12) == 36) }

    @Test("given a missing or zero side, should be nil")
    func incomplete() {
        #expect(PackQuantity.total(boxes: nil, perBox: 12) == nil)
        #expect(PackQuantity.total(boxes: 3, perBox: nil) == nil)
        #expect(PackQuantity.total(boxes: 0, perBox: 12) == nil)
        #expect(PackQuantity.total(boxes: 3, perBox: 0) == nil)
    }

}
