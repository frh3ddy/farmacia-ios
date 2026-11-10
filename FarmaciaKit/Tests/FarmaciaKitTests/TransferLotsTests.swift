import Foundation
import Testing
@testable import FarmaciaKit

/// The product sheet's "Caducidades aquí": this store's lots from GET /inventory/lots
/// (sorted by expiry, not the FIFO order a send takes).
struct TransferLotsTests {
    private let mx = TimeZone(identifier: "America/Mexico_City")!
    /// 10 nov 2026, noon in Mexico City.
    private let now = ISO8601DateFormatter().date(from: "2026-11-10T18:00:00Z")!

    private func rows(_ lots: [CurrentLot], onHand: Int?) -> [TransferLots.Row] {
        TransferLots.rows(lots, onHand: onHand, now: now, timeZone: mx)
    }

    @Test("given 6 expiring 15 mar 2027 with lot A12, should read its count, day and lot in neutral")
    func farOff() {
        #expect(rows([CurrentLot(quantity: 6, expiryDate: "2027-03-15", batchNumber: "A12")], onHand: 6)
            == [.init(text: "6 · vence 15 mar 2027 · lote A12", tone: .neutral)])
    }

    @Test("given a lot expiring in 40 days, should be caution")
    func soon() {
        #expect(rows([CurrentLot(quantity: 2, expiryDate: "2026-12-20", batchNumber: nil)], onHand: 2).first?.tone == .caution)
    }

    @Test("given a lot past its day, should read venció in critical, without a lote when it has none")
    func expired() {
        #expect(rows([CurrentLot(quantity: 2, expiryDate: "2026-10-03", batchNumber: nil)], onHand: 2)
            == [.init(text: "2 · venció 3 oct 2026", tone: .critical)])
    }

    @Test("given a lot with a number but no expiry, should read sin caducidad with its lote")
    func lotWithoutExpiry() {
        #expect(rows([CurrentLot(quantity: 3, expiryDate: nil, batchNumber: "B7")], onHand: 3)
            == [.init(text: "3 · sin caducidad · lote B7", tone: .neutral)])
    }

    @Test("given 10 on hand and lots covering 6, should add 4 sin caducidad registrada")
    func uncovered() {
        #expect(rows([CurrentLot(quantity: 6, expiryDate: "2027-03-15", batchNumber: nil)], onHand: 10).last
            == .init(text: "4 sin caducidad registrada", tone: .neutral))
    }

    @Test("given no lots and 10 on hand, should read only 10 sin caducidad registrada")
    func noLots() {
        #expect(rows([], onHand: 10) == [.init(text: "10 sin caducidad registrada", tone: .neutral)])
        #expect(rows([], onHand: 0).isEmpty)
    }

    @Test("given lots in any order, should list them soonest expiry first")
    func sorted() {
        let lots = [CurrentLot(quantity: 1, expiryDate: "2027-08-01", batchNumber: nil),
                    CurrentLot(quantity: 1, expiryDate: "2027-02-01", batchNumber: nil)]
        #expect(rows(lots, onHand: 2).map(\.text) == ["1 · vence 1 feb 2027", "1 · vence 1 ago 2027"])
    }
}
