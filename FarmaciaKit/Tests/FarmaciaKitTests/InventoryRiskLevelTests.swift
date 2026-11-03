import Foundation
import Testing
@testable import FarmaciaKit

/// Aging risk from GET /inventory/aging/* (`riskLevel`, `severity`).
struct InventoryRiskLevelTests {
    @Test("given Bajo / Medio / Alto / Crítico, tone should be positive / caution / critical / critical",
          arguments: [(InventoryRiskLevel.low, Tone.positive), (.medium, .caution), (.high, .critical), (.critical, .critical)])
    func tone(level: InventoryRiskLevel, expected: Tone) {
        #expect(level.tone == expected)
    }

    @Test("given the API's raw value, should decode it")
    func decodes() throws {
        let level = try JSONDecoder().decode(InventoryRiskLevel.self, from: Data(#""HIGH""#.utf8))
        #expect(level == .high)
        #expect(level.displayName == "Alto")
    }
}
