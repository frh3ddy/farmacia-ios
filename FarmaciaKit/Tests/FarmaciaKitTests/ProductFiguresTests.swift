import Testing
@testable import FarmaciaKit

struct ProductFiguresTests {
    @Test("given cost 14 and stock 18, should have stock value 252")
    func stockValue() {
        let f = ProductFigures(price: 20, cost: 14, stock: 18, tracksInventory: true, canViewCosts: true)
        #expect(f.stockValue == 252)
    }

    @Test("given a role that can't view costs, should have no cost, value or margin")
    func cashier() {
        let f = ProductFigures(price: 20, cost: 14, stock: 18, tracksInventory: true, canViewCosts: false)
        #expect(f.price == 20)
        #expect(f.stock == 18)
        #expect(f.cost == nil)
        #expect(f.stockValue == nil)
        #expect(f.marginPercent == nil)
    }

    @Test("given no stock on hand, should have no stock value", arguments: [0, -3])
    func noStock(stock: Int) {
        let f = ProductFigures(price: 20, cost: 14, stock: stock, tracksInventory: true, canViewCosts: true)
        #expect(f.stock == stock)
        #expect(f.stockValue == nil)
    }

    @Test("given an item that doesn't track stock, should have no stock or value")
    func yastas() {
        let f = ProductFigures(price: nil, cost: 14, stock: 5, tracksInventory: false, canViewCosts: true)
        #expect(f.stock == nil)
        #expect(f.stockValue == nil)
    }

    @Test("given unknown stock tracking, should count it as tracked")
    func trackingUnknown() {
        let f = ProductFigures(price: 20, cost: 14, stock: 5, tracksInventory: nil, canViewCosts: true)
        #expect(f.stockValue == 70)
    }

    @Test("given price 20 and cost 14, should have a 30% margin")
    func margin() {
        let f = ProductFigures(price: 20, cost: 14, stock: 1, tracksInventory: true, canViewCosts: true)
        #expect(f.marginPercent == 30)
    }
}
