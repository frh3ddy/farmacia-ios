import Foundation
import Testing
@testable import FarmaciaKit

struct LotScanMetricsTests {
    let date = Date(timeIntervalSince1970: 1_795_000_000)

    @Test("given a lab read the user edited, a live-text read and a give-up, should export a header plus one row each")
    func csv() {
        let rows = [
            LotScanMetrics(date: date, device: "iPhone14,2", reader: .lab, lot: "D26U908", expiry: MonthYear(year: 2028, month: 7),
                           msToExpiry: 840, msToLot: 410, passes: 12, filter: .dotJoin, edited: true),
            LotScanMetrics(date: date, device: "iPhone16,1", reader: .liveText, lot: nil, expiry: MonthYear(year: 2027, month: 5),
                           msToExpiry: 1200, msToLot: nil, passes: nil, filter: nil, edited: false),
            LotScanMetrics(date: date, device: "iPhone14,2", reader: .lab, lot: nil, expiry: nil,
                           msToExpiry: nil, msToLot: nil, passes: 40, filter: nil, edited: nil),
        ]
        #expect(LotScanMetrics.csv(rows) == """
            date,device,reader,outcome,lot,expiry,ms_to_expiry,ms_to_lot,passes,filter,edited
            2026-11-18T11:06:40Z,"iPhone14,2",lab,read,D26U908,2028-07,840,410,12,dotJoin,yes
            2026-11-18T11:06:40Z,"iPhone16,1",liveText,read,,2027-05,1200,,,,no
            2026-11-18T11:06:40Z,"iPhone14,2",lab,none,,,,,40,,

            """)
    }

    @Test("given saved metrics, should decode back to the same rows")
    func roundTrips() throws {
        let row = LotScanMetrics(date: date, device: "iPhone14,2", reader: .lab, lot: "A1", expiry: MonthYear(year: 2027, month: 1),
                                 msToExpiry: 1, msToLot: 2, passes: 3, filter: .relief, edited: false)
        #expect(try JSONDecoder().decode([LotScanMetrics].self, from: JSONEncoder().encode([row])) == [row])
    }
}
