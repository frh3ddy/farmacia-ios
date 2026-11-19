import Testing
@testable import FarmaciaKit

struct LotVoteTests {
    let today = MonthYear(year: 2026, month: 11)
    let may27 = MonthYear(year: 2027, month: 5)

    private func vote(_ passes: [[String]]) -> LotVote {
        var vote = LotVote(today: today)
        for lines in passes { vote.add(LotScan(lines: lines, barcodes: [], today: today)) }
        return vote
    }

    @Test("given a date read once, should take it right away: the date is what matters")
    func dateAtOnce() {
        #expect(vote([["LOTE: D26U908"], ["CAD MAY 27"]]).expiry == may27)
        #expect(vote([["LOTE: D26U908"]]).expiry == nil)
    }

    @Test("given the date in a later pass, should keep the first one: the scanner closes on it")
    func firstDate() {
        #expect(vote([["CAD MAY 27"], ["CAD MAR 27"]]).expiry == may27)
    }

    @Test("given 2 reads needed (a setting for after the bench), should wait for the second matching read")
    func twoReadsSetting() {
        var vote = LotVote(today: today, votesNeeded: 2)
        vote.add(LotScan(lot: nil, expiry: may27))
        #expect(vote.expiry == nil)
        vote.add(LotScan(lot: nil, expiry: MonthYear(year: 2027, month: 3)))
        vote.add(LotScan(lot: nil, expiry: may27))
        #expect(vote.expiry == may27)
    }

    @Test("given lots D26U908 twice and 026U908 once, should pick D26U908")
    func lotPlurality() {
        #expect(vote([["LOTE: D26U908"], ["LOTE: 026U908"], ["LOTE: D26U908"]]).lot == "D26U908")
    }

    @Test("given two lots read as often, should pick the longer: an edge digit is the usual miss")
    func lotTie() {
        #expect(vote([["LOTE: 513302288"], ["LOTE: 5133022884"]]).lot == "5133022884")
    }

    @Test("given a past date or one over 6 years out after CAD (a smudged digit), should not take it; then the real one",
          arguments: ["CAD JUL 17", "CAD JUL 37"])
    func implausibleDate(misread: String) {
        #expect(vote([[misread]]).expiry == nil)
        #expect(vote([[misread], ["CAD JUL 27"]]).expiry == MonthYear(year: 2027, month: 7))
    }

    @Test("given 0 reads needed, should still need 1")
    func votesFloor() {
        var vote = LotVote(today: today, votesNeeded: 0)
        #expect(vote.votesNeeded == 1)
        #expect(vote.expiry == nil)
        vote.add(LotScan(lot: nil, expiry: may27))
        #expect(vote.expiry == may27)
    }
}
