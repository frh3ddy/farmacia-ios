import Foundation
import Testing
@testable import FarmaciaKit

struct AdjustmentTypeTests {
    private func decode(_ raw: String) throws -> AdjustmentType {
        try JSONDecoder().decode(AdjustmentType.self, from: Data("\"\(raw)\"".utf8))
    }

    @Test("given OPENING_COUNT, should decode as Conteo inicial, counted like a correction")
    func openingCount() throws {
        let type = try decode("OPENING_COUNT")
        #expect(type == .openingCount)
        #expect(type.displayName == "Conteo inicial")
        #expect(type.isVariable)
        #expect(!type.isNegative)
    }

    @Test("given a type from a newer server, should still decode, so the history list can't break")
    func unknownType() throws {
        let type = try decode("SOMETHING_NEW")
        #expect(type == .unknown)
        #expect(type.displayName == "Ajuste")
    }

    @Test("given a raw server type, should read its Spanish name; unknown ones pass through")
    func label() {
        #expect(AdjustmentType.label("DAMAGE") == "Daño")
        #expect(AdjustmentType.label("SOMETHING_NEW") == "SOMETHING_NEW")
    }
}
