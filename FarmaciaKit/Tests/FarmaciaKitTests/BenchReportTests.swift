import Testing
@testable import FarmaciaKit

struct BenchReportTests {
    private func result(_ expected: String?, _ read: String?, ms: Double = 10) -> BenchReport.Result {
        BenchReport.Result(expected: expected, read: read, ms: ms)
    }

    @Test("given 9 of 10 coded images read correctly, should report a 90% read rate")
    func readRate() {
        let results = Array(repeating: result("4006381333931", "4006381333931"), count: 9) + [result("96385074", nil)]
        let report = BenchReport(results)
        #expect(report.images == 10 && report.hits == 9)
        #expect(report.readRate == 0.9)
    }

    @Test("given a read that differs from the expected code, should count an accepted misread, not a hit")
    func misread() {
        let report = BenchReport([result("4006381333931", "4006381333948")])
        #expect(report.hits == 0 && report.misreads == 1)
    }

    @Test("given a code read off a photo with no code, should count a misread and leave the read rate alone")
    func falsePositive() {
        let report = BenchReport([result("96385074", "96385074"), result(nil, "96385074"), result(nil, nil)])
        #expect(report.misreads == 1)
        #expect(report.readRate == 1)
    }

    @Test("given times 10, 20 and 300 ms, should report a 20 ms median", arguments: [
        ([10.0, 20, 300], 20.0),
        ([10.0, 20, 30, 300], 25.0),
    ])
    func median(times: [Double], expected: Double) {
        #expect(BenchReport(times.map { result("96385074", "96385074", ms: $0) }).medianMS == expected)
    }

    @Test("given a fixture filename, should take the expected code after the last underscore; _none means no code", arguments: [
        ("shiny-curved_4006381333931.jpg", "4006381333931"),
        ("qr-and-ean_96385074.heic", "96385074"),
        ("blank-box_none.jpg", nil),
        ("no-underscore.jpg", nil),
    ])
    func expectedCode(filename: String, expected: String?) {
        #expect(BenchReport.expectedCode(fromFilename: filename) == expected)
    }
}
