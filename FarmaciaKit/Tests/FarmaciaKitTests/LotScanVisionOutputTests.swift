import Testing
@testable import FarmaciaKit

/// What Apple's Vision text recognizer (the engine behind Live Text) actually returned for the box
/// photos (IMG_5659–5666, 2026-11-06), lines top to bottom. Unlike `LotScanPhotoTests`, these are
/// real outputs, misreads included.
struct LotScanVisionOutputTests {
    let today = MonthYear(year: 2026, month: 11)

    private func scan(_ lines: [String]) -> LotScan { LotScan(lines: lines, barcodes: [], today: today) }

    @Test("IMG_5659: AGO28 read as \"A6028\" can't be told from a lote code, so it's missed, never guessed")
    func ago28AsA6028Missed() {
        let s = scan(["Lote:", "Caducidad:", "Precio Máximo al Público:", "26341048", "$149.23", "A6028"])
        #expect(s.expiry == nil)
    }

    // Review (dev-79, 2026-11-07): "A60" before a year is also what a lote code looks like.

    @Test("given a lote code like A6029, should never read it as the caducidad")
    func lotCodeNotDate() {
        let s = scan(["Lote: A6029"])
        #expect(s.lot == "A6029")
        #expect(s.expiry == nil)
    }

    @Test("given a lote code like A6029 near the caducidad, should not block it as a second date")
    func lotCodeDoesNotBlock() {
        #expect(scan(["Lote:", "A6029", "ENE 27"]).expiry == MonthYear(year: 2027, month: 1))
    }

    @Test("IMG_5666: \"254875 A60 27\" among the nutrition table")
    func a60() {
        let s = scan([
            "res por envase: 30", "Por porción", "17,26 kJ", "0,134g", "(4,18 kcal)", "200mg", "300kg",
            "parcón: 700 mg (1 cápsula)", "Por 100g", "2 465 kJ", "(597 kcal)", "28,57 g", "42,86mg",
            "Fecha de caducidad:", "Precio máximo al público:", "254875 A60 27", "$360.00",
            "30 °C. No se eto", "Hecho en México", "Metalurgia No. 280", "C.P. 45593, Порир",
        ])
        #expect(s.expiry == MonthYear(year: 2027, month: 8))
        #expect(s.lot == "254875")
    }

    @Test("IMG_5660: the price read as \"< 10.00\" must not block the caducidad")
    func priceAsLessThan() {
        let s = scan(["Lote:", "Caducidad:", "Precio máximo al público:", "25010 1", "ENE 27", "< 10.00"])
        #expect(s.expiry == MonthYear(year: 2027, month: 1))
    }

    @Test("IMG_5661: labels interleaved, the day on its own line")
    func interleaved() {
        let s = scan(["LOTE No.:", "FECHA DE", "PRECIO MÁXIMO", "CADUCIDAD:", "AL PÚBLICO:",
                      "262009", "09", ". FEB 28", "$", "186.00"])
        #expect(s.expiry == MonthYear(year: 2028, month: 2))
        #expect(s.lot == "262009")
    }

    @Test("IMG_5662: each value right under its label, OCT read with a zero")
    func underLabels() {
        let s = scan(["Lote:", "25142644", "Caducidad:", "0CT 27", "$132.00", "Precio Maximo", "al Público:"])
        #expect(s.expiry == MonthYear(year: 2027, month: 10))
        #expect(s.lot == "25142644")
    }

    @Test("IMG_5663 (full resolution) and IMG_5664: a price with a stray symbol and a space, a time")
    func strayPriceSymbols() {
        let a = scan(["Lote:", "Caducidad:", "Precio máximo al público:", "255004", "SEP 27", "+138. 00", "10:11"])
        #expect(a.expiry == MonthYear(year: 2027, month: 9))
        #expect(a.lot == "255004")
        let b = scan(["Lote:", "Caducidad:", "Precio máximo al público:", "255933", "OCT 27", "#156. 00", "11:56"])
        #expect(b.expiry == MonthYear(year: 2027, month: 10))
        #expect(b.lot == "255933")
    }
}
