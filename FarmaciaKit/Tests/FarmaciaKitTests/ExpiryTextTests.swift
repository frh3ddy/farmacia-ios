import Testing
@testable import FarmaciaKit

struct ExpiryTextTests {
    let today = MonthYear(year: 2026, month: 11)

    @Test("given CAD 03/2027, should read March 2027")
    func cadSlash() {
        #expect(ExpiryText.read(lines: ["CAD 03/2027"], today: today) == MonthYear(year: 2027, month: 3))
    }

    @Test("given the label formats seen on boxes, should read March 2027", arguments: [
        "CAD. 03-27", "EXP 2027/03", "VENCE MAR 2027", "EXP: MAR-2027", "CAD: 15/03/2027",
        "Caducidad 3/2027", "cad 03.27", "EXP. 03 2027", "Caducidad: marzo 2027", "VTO 15 MAR 27",
    ])
    func formats(line: String) {
        #expect(ExpiryText.read(lines: [line], today: today) == MonthYear(year: 2027, month: 3))
    }

    @Test("given CAD ENE 28, should read January 2028")
    func spanishMonth() {
        #expect(ExpiryText.read(lines: ["CAD ENE 28"], today: today) == MonthYear(year: 2028, month: 1))
    }

    @Test("given CAD on one line and the date on the next, should read it")
    func nextLine() {
        #expect(ExpiryText.read(lines: ["CAD.", "03/2027"], today: today) == MonthYear(year: 2027, month: 3))
    }

    @Test("given text with no date, should read nothing", arguments: ["LOTE A23B45", "CAD", "Tabletas 500 mg"])
    func noDate(line: String) {
        #expect(ExpiryText.read(lines: [line], today: today) == nil)
    }

    @Test("given FAB 01/2025 and CAD 01/2028, should read January 2028", arguments: [
        ["FAB 01/2025", "CAD 01/2028"], ["FAB 01/2025 CAD 01/2028"], ["MFG 2025/01", "EXP 2028/01"],
    ])
    func skipsManufacturing(lines: [String]) {
        #expect(ExpiryText.read(lines: lines, today: today) == MonthYear(year: 2028, month: 1))
    }

    @Test("given a date with no keyword, should read it when it's the only one and still ahead")
    func looseDate() {
        #expect(ExpiryText.read(lines: ["Lote 23A45", "03/2027"], today: today) == MonthYear(year: 2027, month: 3))
    }

    @Test("given a FAB date and an unlabeled date, should read the unlabeled one")
    func looseDateBesideFab() {
        #expect(ExpiryText.read(lines: ["FAB 01/2025", "01/2028"], today: today) == MonthYear(year: 2028, month: 1))
    }

    @Test("given dates with no keyword, should read nothing when there are two, one is a FAB date, or it has passed",
          arguments: [["01/2025", "01/2028"], ["FAB 01/2025"], ["03/2026"]])
    func looseDateRejected(lines: [String]) {
        #expect(ExpiryText.read(lines: lines, today: today) == nil)
    }
}

extension ExpiryTextTests {
    @Test("given a word before an unlabeled date, should still read the date")
    func wordBeforeDate() {
        #expect(ExpiryText.read(lines: ["Lote 03/2027"], today: today) == MonthYear(year: 2027, month: 3))
    }
}

/// Dot-matrix and embossed months read with one wrong character (photos IMG_5794, IMG_5797).
extension ExpiryTextTests {
    @Test("given a month with one misread character before a 2-digit year, should read the month",
          arguments: [("KAY 27", 5, 2027), ("HAY 27", 5, 2027), ("M4Y 27", 5, 2027), ("IUL 28", 7, 2028)])
    func oneCharacterMonth(line: String, month: Int, year: Int) {
        #expect(ExpiryText.read(lines: [line], today: today) == MonthYear(year: year, month: month))
    }

    @Test("given a real word one letter from a month (review dev-f8), should read nothing: only OCR-confusable letters count",
          arguments: ["1 AL DIA 30 TABLETAS", "PAR 27", "NOS 27", "ABS 27", "ONE 28",
                      "DIA 2030", "CON 2027", "LOT 2028", "REG 2029", "BIO 2027", "SOL 2028", "DOS 2030"])
    func wordsAreNotMonths(line: String) {
        #expect(ExpiryText.read(lines: [line], today: today) == nil)
    }

    @Test("given a misread month that's one character from two months, should read nothing")
    func ambiguousMonth() {
        #expect(ExpiryText.read(lines: ["JUI 27"], today: today) == nil)
    }

    @Test("given MMYY glued or spaced after its keyword (IMG_5837), should read the month and year", arguments: [
        ("CAD0228", 2, 2028), ("CADO228", 2, 2028), ("EXP1229", 12, 2029), ("VTO1027", 10, 2027),
        ("VENCE0330", 3, 2030), ("CAD 0228", 2, 2028), ("CAD: O228", 2, 2028), ("EXP. 1229", 12, 2029),
    ])
    func keywordMonthYear(line: String, month: Int, year: Int) {
        #expect(ExpiryText.read(lines: [line], today: today) == MonthYear(year: year, month: month))
    }

    @Test("given 4 digits that aren't MMYY after a keyword, or no keyword, should read nothing (review dev-f8)",
          arguments: ["CAD0228X", "CAD022028", "EXP2812", "CAD 2028", "CAD 0028", "LOTE A0228", "LOTE 0228"])
    func notKeywordMonthYear(line: String) {
        #expect(ExpiryText.read(lines: [line], today: today) == nil)
    }

    @Test("given FAB before a 2-digit year, should not read it as FEB")
    func fabIsNotFeb() {
        #expect(ExpiryText.read(lines: ["FAB 28"], today: today) == nil)
        #expect(ExpiryText.read(lines: ["MAR 27 FAB 25"], today: today) == MonthYear(year: 2027, month: 3))
    }
}
