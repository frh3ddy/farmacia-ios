import Testing
@testable import FarmaciaKit

struct LotNumberTests {
    @Test("given LOTE: A23B45, should read A23B45")
    func loteColon() {
        #expect(LotNumber.read(lines: ["LOTE: A23B45"]) == "A23B45")
    }

    @Test("given the lot formats seen on boxes, should read the lot", arguments: [
        ("LOT A23B45", "A23B45"), ("L. 2304567", "2304567"), ("LT:XK12", "XK12"),
        ("Lote 23-0456", "23-0456"), ("No. de lote: b7731", "B7731"), ("LOTE Nº 4411A", "4411A"),
    ])
    func formats(line: String, lot: String) {
        #expect(LotNumber.read(lines: [line]) == lot)
    }

    @Test("given LOTE on one line and the lot on the next, should read it")
    func nextLine() {
        #expect(LotNumber.read(lines: ["LOTE", "A23B45"]) == "A23B45")
    }

    @Test("given the lot and the expiry on one line, should stop the lot before CAD")
    func stopsBeforeExpiry() {
        #expect(LotNumber.read(lines: ["LOTE: A23B45 CAD 03/27"]) == "A23B45")
    }

    @Test("given text with no lot, should read nothing", arguments: ["CAD 03/2027", "Paracetamol 500 mg", "LOTE", "Solución 120 ML"])
    func noLot(line: String) {
        #expect(LotNumber.read(lines: [line]) == nil)
    }
}
