import Testing
@testable import FarmaciaKit

/// Recibir's previous cost (the field's "Anterior" hint and the "vs último" line): the
/// selected supplier's last cost, else the latest receiving's (named, since it's another
/// supplier's), else the product's average.
struct PreviousCostTests {
    private let nadro = ReceivingPrice.PreviousCost(cost: 16.5, supplierName: "Nadro")

    @Test("given the selected supplier has a last cost, should use it, unnamed")
    func supplierLastWins() {
        #expect(ReceivingPrice.previous(supplierLast: 18, lastReceiving: nadro, average: 15)
                == .init(cost: 18, supplierName: nil))
    }

    @Test("given a supplier with no history for this product, should use the latest receiving, naming its supplier")
    func latestReceiving() {
        #expect(ReceivingPrice.previous(supplierLast: nil, lastReceiving: nadro, average: 15) == nadro)
    }

    @Test("given no supplier cost and no receiving (or a free one at $0), should fall back to the average")
    func average() {
        #expect(ReceivingPrice.previous(supplierLast: nil, lastReceiving: nil, average: 15) == .init(cost: 15, supplierName: nil))
        #expect(ReceivingPrice.previous(supplierLast: nil, lastReceiving: .init(cost: 0, supplierName: "Regalo"), average: 15)
                == .init(cost: 15, supplierName: nil))
        #expect(ReceivingPrice.previous(supplierLast: nil, lastReceiving: nil, average: nil) == nil)
    }

    @Test("given the newest receiving a $0 gift, should use the newest one with a cost, not jump to the average")
    func skipsGift() {
        let rows: [(unitCost: String, supplierName: String?)] = [("0", "Regalo"), ("16.50", "Nadro"), ("15", "Fanasa")]
        #expect(ReceivingPrice.lastReceiving(newestFirst: rows) == nadro)
        #expect(ReceivingPrice.lastReceiving(newestFirst: [(unitCost: "0", supplierName: nil)]) == nil)
    }

    @Test("given no receivings (stock from the migration) but suppliers on record, should use the product detail's supplier (preferred, else first), named")
    func supplierOnRecord() {
        let fanasa = UnitCost.Supplier(id: "f", name: "Fanasa", cost: 15, isPreferred: false, lastPurchase: nil)
        let nadroPreferred = UnitCost.Supplier(id: "n", name: "Nadro", cost: 16.5, isPreferred: true, lastPurchase: nil)
        let onRecord = ReceivingPrice.supplierOnRecord([fanasa, nadroPreferred])
        #expect(onRecord == nadro)
        #expect(ReceivingPrice.previous(supplierLast: nil, lastReceiving: nil, onRecord: onRecord, average: 12) == nadro)
        #expect(ReceivingPrice.supplierOnRecord([]) == nil)
    }

    @Test("given a receiving and suppliers on record, the receiving (what was actually paid last) should win")
    func receivingBeforeOnRecord() {
        let fanasa = ReceivingPrice.PreviousCost(cost: 15, supplierName: "Fanasa")
        #expect(ReceivingPrice.previous(supplierLast: nil, lastReceiving: nadro, onRecord: fanasa, average: 12) == nadro)
    }

    @Test("given $18 typed against Nadro's last $16.50, the line should say whose cost it compares with")
    func namedChange() {
        #expect(CostChange(current: 18, last: 16.5, supplierName: "Nadro")?.text == "▲ 9% vs último $16.50 (Nadro)")
    }

    @Test("given the selected supplier's own cost, the line should read as before")
    func unnamedChange() {
        #expect(CostChange(current: 18, last: 16.5)?.text == "▲ 9% vs último $16.50")
    }
}
