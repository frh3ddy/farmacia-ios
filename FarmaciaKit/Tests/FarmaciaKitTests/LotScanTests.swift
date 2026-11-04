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
}
