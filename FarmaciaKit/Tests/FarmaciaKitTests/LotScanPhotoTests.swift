import Testing
@testable import FarmaciaKit

/// Real boxes (photos 2026-11-06, IMG_5659–5666): "Lote:" and "Caducidad:" printed in a header,
/// the values inkjet-printed elsewhere, often dot-matrix. Lines as live text reads them, top to bottom.
struct LotScanPhotoTests {
    let today = MonthYear(year: 2026, month: 11)

    private func scan(_ lines: [String]) -> LotScan { LotScan(lines: lines, barcodes: [], today: today) }

    @Test("IMG_5659: lote, caducidad and price on one line, the year glued to the month")
    func oneLineGlued() {
        let s = scan(["Lote:", "Caducidad:", "Precio Máximo al Público:", "26341048 AGO28 $149.23"])
        #expect(s.lot == "26341048")
        #expect(s.expiry == MonthYear(year: 2028, month: 8))
        #expect(scan(["Lote:", "Caducidad:", "26341048 AG028 $149.23"]).expiry == MonthYear(year: 2028, month: 8))
    }

    @Test("IMG_5660: spaced dot-matrix, the lote on the line above the caducidad")
    func spaced() {
        let s = scan(["Lote:", "Caducidad:", "Precio máximo al público:", "2 5 0 1 0 1 7 8", "E N E  2 7", "$ 2 1 0 . 0 0"])
        #expect(s.lot == "25010178")
        #expect(s.expiry == MonthYear(year: 2027, month: 1))
    }

    @Test("IMG_5661: \"LOTE No.:\" header, a day in the caducidad")
    func dayMonthYear() {
        let s = scan(["LOTE No.:", "FECHA DE", "CADUCIDAD:", "PRECIO MÁXIMO", "AL PÚBLICO:", "262009", "09 FEB 28", "$ 186.00"])
        #expect(s.lot == "262009")
        #expect(s.expiry == MonthYear(year: 2028, month: 2))
    }

    @Test("IMG_5662: address above, OCT read with a zero")
    func addressAndZero() {
        let s = scan([
            "Hecho en México por: PRODUCTOS FARMACÉUTICOS COLLINS, S.A. de C.V.",
            "Av. López Mateos No. 1938, Col. Agua Blanca Industrial, C.P. 45235, Zapopan, Jalisco, México.",
            "Lote:", "Caducidad:", "25142644 0CT 27", "$132.00", "Precio Máximo", "al Público:",
        ])
        #expect(s.lot == "25142644")
        #expect(s.expiry == MonthYear(year: 2027, month: 10))
    }

    @Test("IMG_5663 and 5664: a time printed under the caducidad, lines apart")
    func withTime() {
        let a = scan(["Lote:", "Caducidad:", "Precio máximo al público:", "255004 SEP 27", "$138.00 10:11"])
        #expect(a.lot == "255004")
        #expect(a.expiry == MonthYear(year: 2027, month: 9))
        let b = scan(["Lote:", "Caducidad:", "Precio máximo al público:", "255933", "OCT 27", "$156.00", "11:56"])
        #expect(b.lot == "255933")
        #expect(b.expiry == MonthYear(year: 2027, month: 10))
    }

    @Test("IMG_5665: labels in a column, values in a block")
    func column() {
        let s = scan(["Lote:", "Caducidad:", "Precio máximo", "al público:", "25082350", "AGO 27", "$140.00"])
        #expect(s.lot == "25082350")
        #expect(s.expiry == MonthYear(year: 2027, month: 8))
    }

    @Test("IMG_5666: the lote glued to the month, AGO read with a zero, a nutrition table around")
    func gluedLot() {
        let s = scan([
            "Por porción Por 100g", "17,26 kJ 2 465 kJ", "200mg 28,57 g",
            "254875AG0 27", "$360.00", "Lote:", "Fecha de caducidad:", "Precio máximo al público:",
        ])
        #expect(s.lot == "254875")
        #expect(s.expiry == MonthYear(year: 2027, month: 8))
    }

    @Test("given a price that looks like a date, should never read it as the caducidad")
    func priceNotDate() {
        #expect(scan(["Caducidad:", "$10.30"]).expiry == nil)
        #expect(scan(["$ 12.25", "OCT 27"]).expiry == MonthYear(year: 2027, month: 10))
    }

    @Test("given a box with no \"Lote\" or \"Cad\" labels, should still read the number printed with the caducidad")
    func noLabels() {
        let s = scan(["255933", "OCT 27", "$156.00"])
        #expect(s.lot == "255933")
        #expect(s.expiry == MonthYear(year: 2027, month: 10))
        #expect(scan(["255004 SEP 27"]).lot == "255004")
    }

    @Test("given a lote printed before CAD on its line, should read it")
    func lotBeforeKeyword() {
        #expect(scan(["B24017 CAD 08/2027"]).lot == "B24017")
    }

    @Test("given amounts with units near the caducidad (100g, 700mg), should not take them for the lote")
    func unitsNotLot() {
        #expect(scan(["Por 100g", "OCT 27"]).lot == nil)
        #expect(scan(["700MG 30 CAPSULAS", "OCT 27"]).lot == nil)
    }

    // Review (dev-ee, 2026-11-06): numbers near the inkjet block that aren't the lote.

    @Test("given the sanitary registration near the caducidad, should not take it for the lote")
    func registrationNotLot() {
        let s = scan(["Lote: Caducidad:", "Reg. No. 123M2015 SSA IV", "AGO 27"])
        #expect(s.lot == nil)
        #expect(s.expiry == MonthYear(year: 2027, month: 8))
    }

    @Test("given the barcode digits near the caducidad, should not take them for the lote")
    func gtinNotLot() {
        let s = scan(["Lote: Caducidad:", "7501234567890", "08/2027"])
        #expect(s.lot == nil)
        #expect(s.expiry == MonthYear(year: 2027, month: 8))
    }

    @Test("given a lote code with a month inside (A23DIC45), should not read it as a second date")
    func monthInsideLotCode() {
        #expect(scan(["A23DIC45", "08/2027"]).expiry == MonthYear(year: 2027, month: 8))
    }

    @Test("given the caducidad, should close right away, with or without a lote")
    func caducidadCloses() {
        #expect(scan(["Lote:", "Caducidad:", "255933", "OCT 27"]).autoAccept == .now)
        #expect(scan(["LOTE: A23B45", "CAD 03/2027"]).autoAccept == .now)
    }

    @Test("given \"Lote:\" with the barcode digits or the registration on the next line, should not take them for the lote")
    func labeledNextLineNotGtin() {
        let gtin = scan(["Lote:", "7501234567890", "CAD 08/2027"])
        #expect(gtin.lot == nil)
        #expect(gtin.expiry == MonthYear(year: 2027, month: 8))
        #expect(scan(["Lote:", "123M2015", "CAD 08/2027"]).lot == nil)
        #expect(scan(["Lote:", "25010178", "CAD 08/2027"]).lot == "25010178")
    }

    // Review (dev-ee, 2026-11-06), with instant accept: a wrong date or lote now lands at once.

    @Test("given a price without its $ (PRECIO MAX 12.50, P.M.P. 12.50), should not read it as the caducidad")
    func priceWithoutDollar() {
        #expect(scan(["PRECIO MAX 12.50"]).expiry == nil)
        #expect(scan(["P.M.P. 12.50"]).expiry == nil)
        #expect(scan(["PRECIO MAX 12.50", "OCT 27"]).expiry == MonthYear(year: 2027, month: 10))
    }

    @Test("given a date more than 6 years away with no keyword, should not take it: no medicine lasts that long")
    func tooFarAway() {
        #expect(scan(["12.50"]).expiry == nil)
        #expect(scan(["11/2032"]).expiry == MonthYear(year: 2032, month: 11))
        #expect(scan(["12/2032"]).expiry == nil)
    }

    @Test("given a postal code or a phone number near the caducidad, should not take it for the lote")
    func postalAndPhoneNotLot() {
        #expect(scan(["Hecho en México por Lab SA de CV", "C.P. 54080 Edo. de Méx.", "OCT 27"]).lot == nil)
        #expect(scan(["Atención 800 1234567", "OCT 27"]).lot == nil)
        #expect(scan(["Tel. 5551234567", "OCT 27"]).lot == nil)
    }
}
