import Testing
@testable import FarmaciaKit

/// Recibir: the selected supplier's last cost, whichever arrives first, the selection
/// (a run supplier, or a tap while loading) or the product's supplier costs. Each event
/// returns the cost to offer, so the form fills it after either one.
struct SelectedSupplierCostTests {
    @Test("given Nadro selected before the product's supplier costs load, loading them should return Nadro's cost to fill in")
    func selectedBeforeCostsLoad() {
        var cost = SelectedSupplierCost()
        #expect(cost.select("nadro") == nil)
        #expect(cost.costsLoaded([("nadro", 42.5), ("fanasa", 40)]) == 42.5)
        #expect(cost.lastCost == 42.5)
    }

    @Test("given the costs loaded first (nothing selected), loading should return nothing; selecting Fanasa should return its cost")
    func costsLoadFirst() {
        var cost = SelectedSupplierCost()
        #expect(cost.costsLoaded([("nadro", 42.5), ("fanasa", 40)]) == nil)
        #expect(cost.select("fanasa") == 40)
    }

    @Test("given a supplier with no cost for this product, or none selected, should have no last cost (the hint falls back to the average)")
    func noCost() {
        var cost = SelectedSupplierCost()
        _ = cost.costsLoaded([("nadro", 42.5)])
        #expect(cost.select("otro") == nil)
        #expect(cost.select(nil) == nil)
        #expect(cost.lastCost == nil)
    }

    @Test("given the same supplier listed twice, should keep the first, as the list shows them (and not crash)")
    func duplicateKeepsFirst() {
        var cost = SelectedSupplierCost()
        _ = cost.select("nadro")
        #expect(cost.costsLoaded([("nadro", 42.5), ("nadro", 50)]) == 42.5)
    }
}
