import Testing
@testable import FarmaciaKit

struct GTINCheckTests {
    @Test("given a GTIN with a correct GS1 check digit, should be valid",
          arguments: ["4006381333931", "96385074", "036000291452", "00012345600012"])
    func valid(code: String) { #expect(GTINCheck.isValid(code)) }

    @Test("given a wrong check digit, should be invalid",
          arguments: ["4006381333932", "96385075", "036000291453"])
    func wrongDigit(code: String) { #expect(!GTINCheck.isValid(code)) }

    @Test("given non-digits or a length other than 8, 12, 13 or 14, should be invalid",
          arguments: ["", "400638133393A", "1234567", "40063813339311", "123456789012345"])
    func malformed(code: String) { #expect(!GTINCheck.isValid(code)) }
}
