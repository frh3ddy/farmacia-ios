import Testing
@testable import FarmaciaKit

struct LotScanTests {
    let today = MonthYear(year: 2026, month: 11)

    @Test("given a DataMatrix and text that disagree, should use the DataMatrix")
    func dataMatrixWins() {
        let scan = LotScan(lines: ["LOTE: X999", "CAD 01/2030"],
                           barcodes: ["0107501234567890" + "17270331" + "1023A45"], today: today)
        #expect(scan.lot == "23A45")
        #expect(scan.expiry == MonthYear(year: 2027, month: 3))
        #expect(scan.isComplete)
    }

    @Test("given only a lot, should not be complete")
    func lotOnly() {
        let scan = LotScan(lines: ["LOTE: A23B45"], barcodes: ["7501234567890"], today: today)
        #expect(scan.lot == "A23B45")
        #expect(scan.expiry == nil)
        #expect(!scan.isComplete)
    }

    @Test("given a DataMatrix without a lot, should take the lot from the text")
    func mixes() {
        let scan = LotScan(lines: ["LOTE: A23B45"], barcodes: ["0107501234567890" + "17270331"], today: today)
        #expect(scan.lot == "A23B45")
        #expect(scan.expiry == MonthYear(year: 2027, month: 3))
    }

    @Test("given both the lot and the caducidad, should accept right away")
    func bothNow() {
        let scan = LotScan(lines: ["LOTE: A23B45", "CAD 03/2027"], barcodes: [], today: today)
        #expect(scan.autoAccept == .now)
    }

    @Test("given only the caducidad, should accept it right away: some boxes show it for a split second")
    func expiryOnlyNow() {
        let scan = LotScan(lines: ["CAD 03/2027"], barcodes: [], today: today)
        #expect(scan.expiry == MonthYear(year: 2027, month: 3))
        #expect(scan.lot == nil)
        #expect(scan.autoAccept == .now)
    }

    @Test("given only a lot, or nothing, should wait for Usar")
    func lotOnlyWaits() {
        #expect(LotScan(lines: ["LOTE: A23B45"], barcodes: [], today: today).autoAccept == .no)
        #expect(LotScan(lines: [], barcodes: [], today: today).autoAccept == .no)
    }

    @Test("given a box with FAB and CAD dates and no readable lote, should take the caducidad alone, never the FAB date")
    func fabAndCadNoLot() {
        let scan = LotScan(lines: ["FAB 01/2025", "CAD 01/2028"], barcodes: [], today: today)
        #expect(scan.expiry == MonthYear(year: 2028, month: 1))
        #expect(scan.autoAccept == .now)
        #expect(LotScan(lines: ["ELAB 10/2026"], barcodes: [], today: today).autoAccept == .no)
    }
}
