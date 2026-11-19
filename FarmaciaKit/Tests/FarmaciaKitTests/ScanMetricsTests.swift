import Foundation
import Testing
@testable import FarmaciaKit

struct ScanMetricsTests {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("given a read, a legacy read and a give-up, should export a header plus one row each (UTC timestamps)")
    func rows() {
        let csv = ScanMetrics.csv([
            ScanMetrics(date: date, device: "iPhone16,1", detector: .vision, code: "4006381333931",
                        msToRead: 412, msSinceOpen: 3150, frames: 13, misreads: 1,
                        topConfidence: 0.734, settingsTag: "wide-1080-v2"),
            ScanMetrics(date: date, device: "iPhone16,1", detector: .legacy, code: "96385074",
                        msToRead: nil, msSinceOpen: 2000, frames: 0, misreads: 0,
                        topConfidence: nil, settingsTag: "legacy"),
            ScanMetrics(date: date, device: "iPhone16,1", detector: .vision, code: nil,
                        msToRead: nil, msSinceOpen: 9000, frames: 240, misreads: 0,
                        topConfidence: 0.41, settingsTag: "wide-1080-v2"),
        ])
        #expect(csv == #"""
        date,device,detector,outcome,code,ms_to_read,ms_since_open,frames,misreads,top_confidence,settings
        2023-11-14T22:13:20Z,"iPhone16,1",vision,read,4006381333931,412,3150,13,1,0.73,wide-1080-v2
        2023-11-14T22:13:20Z,"iPhone16,1",legacy,read,96385074,,2000,0,0,,legacy
        2023-11-14T22:13:20Z,"iPhone16,1",vision,none,,,9000,240,0,0.41,wide-1080-v2

        """#)
    }

    @Test("given a field containing a comma or a quote, should quote it and double the quotes", arguments: [
        ("A,B", #""A,B""#),
        (#"say "hi""#, #""say ""hi""""#),
        ("plain", "plain"),
    ])
    func quoting(field: String, expected: String) {
        #expect(ScanMetrics.csvField(field) == expected)
    }

    @Test("given saved metrics, should decode back to the same rows")
    func roundTrips() throws {
        let rows = [ScanMetrics(date: date, device: "iPhone14,2", detector: .vision, code: nil, msToRead: nil,
                                msSinceOpen: 9000, frames: 240, misreads: 0, topConfidence: 0.41, settingsTag: "x")]
        let decoded = try JSONDecoder().decode([ScanMetrics].self, from: JSONEncoder().encode(rows))
        #expect(decoded == rows)
    }
}
