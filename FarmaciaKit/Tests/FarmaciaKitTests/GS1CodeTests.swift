import Testing
@testable import FarmaciaKit

struct GS1CodeTests {
    let gs = "\u{1D}"

    @Test("given a DataMatrix with GS separators, should read lot 23A45 and expiry March 2027")
    func rawPayload() {
        let code = GS1Code(payload: "]d2" + "0107501234567890" + "172703" + "31" + "1023A45" + gs + "21SN99")
        #expect(code?.lot == "23A45")
        #expect(code?.expiry == MonthYear(year: 2027, month: 3))
    }

    @Test("given the printed form (17)270331(10)23A45, should read the same")
    func printedForm() {
        let code = GS1Code(payload: "(01)07501234567890(17)270331(10)23A45")
        #expect(code?.lot == "23A45")
        #expect(code?.expiry == MonthYear(year: 2027, month: 3))
    }

    @Test("given day 00 in the expiry, should still read the month")
    func dayZero() {
        #expect(GS1Code(payload: "0107501234567890" + "17270300" + "10A1")?.expiry == MonthYear(year: 2027, month: 3))
    }

    @Test("given the lot last with no separator, should read it to the end")
    func lotLast() {
        #expect(GS1Code(payload: "01075012345678901727033110LOT-77")?.lot == "LOT-77")
    }

    @Test("given a plain EAN or a URL, should not be a GS1 lot code", arguments: ["7501234567890", "https://example.com"])
    func notGS1(payload: String) {
        #expect(GS1Code(payload: payload) == nil)
    }
}
