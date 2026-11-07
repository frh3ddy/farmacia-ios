import Foundation
import Testing
@testable import FarmaciaKit

struct ReadingOrderTests {
    @Test("given text blocks in any order, should read them top to bottom")
    func topToBottom() {
        let lines = ReadingOrder.lines([
            ("$156.00", CGRect(x: 10, y: 200, width: 80, height: 20)),
            ("Lote:", CGRect(x: 10, y: 10, width: 40, height: 20)),
            ("255933", CGRect(x: 10, y: 150, width: 80, height: 20)),
        ])
        #expect(lines == ["Lote:", "255933", "$156.00"])
    }

    @Test("given blocks on the same row, a little off level, should read them left to right")
    func sameRow() {
        let lines = ReadingOrder.lines([
            ("OCT 27", CGRect(x: 120, y: 148, width: 60, height: 20)),
            ("255933", CGRect(x: 10, y: 155, width: 80, height: 20)),
        ])
        #expect(lines == ["255933", "OCT 27"])
    }

    @Test("given a block of several lines, should keep its lines in order")
    func multiline() {
        #expect(ReadingOrder.lines([("FECHA DE\nCADUCIDAD:", CGRect(x: 0, y: 0, width: 80, height: 40))])
                == ["FECHA DE", "CADUCIDAD:"])
    }
}
