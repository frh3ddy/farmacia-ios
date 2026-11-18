import Foundation
import Testing
@testable import FarmaciaKit

struct ScanMetricsTests {
    private func scan(_ code: String, detector: ScanMetrics.Detector = .vision) -> ScanMetrics {
        ScanMetrics(date: Date(timeIntervalSince1970: 1_700_000_000), device: "iPhone16,1", detector: detector,
                    code: code, msToRead: 412, frames: 13, misreads: 1, settingsTag: "wide-1080-v2")
    }

    @Test("given two scans, should export a header plus one row per scan (UTC timestamps)")
    func rows() {
        let csv = ScanMetrics.csv([scan("4006381333931"), scan("96385074", detector: .legacy)])
        #expect(csv == #"""
        date,device,detector,code,ms_to_read,frames,misreads,settings
        2023-11-14T22:13:20Z,"iPhone16,1",vision,4006381333931,412,13,1,wide-1080-v2
        2023-11-14T22:13:20Z,"iPhone16,1",legacy,96385074,412,13,1,wide-1080-v2

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
}
