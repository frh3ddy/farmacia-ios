import Foundation
import Testing
@testable import FarmaciaKit

/// The Lotes chip: neutral unless something needs attention; the worst problem wins.
struct ProductAlertTests {
    let day: TimeInterval = 86_400

    func lot(expiresIn days: Double? = nil) -> BatchValuation {
        BatchValuation(batchId: UUID().uuidString, quantity: 1, receivedAt: Date(), age: 5,
                       expiryDate: days.map { Date().addingTimeInterval($0 * day) })
    }

    @Test("given an expired lot and low aging risk, should be critical \"Vencido\"")
    func expired() {
        let alert = ProductAlert.worst(lots: LotSummary(lots: [lot(expiresIn: -3), lot()]), stockHere: 2, risk: .low)
        #expect(alert.tone == .critical)
        #expect(alert.label == "1 lote vencido")
    }

    @Test("given everything healthy, should be neutral — never green by default")
    func healthy() {
        let alert = ProductAlert.worst(lots: LotSummary(lots: [lot(expiresIn: 400)]), stockHere: 2, risk: .low)
        #expect(alert.tone == .neutral)
        #expect(alert.label == "Sin alertas")
    }

    @Test("given 1 unit here, should stay neutral (no fixed low-stock rule)")
    func oneUnit() {
        #expect(ProductAlert.worst(lots: LotSummary(lots: [lot()]), stockHere: 1, risk: nil).tone == .neutral)
    }

    @Test("given 0 units here, should be critical \"Agotado\"")
    func out() {
        let alert = ProductAlert.worst(lots: LotSummary(lots: []), stockHere: 0, risk: nil)
        #expect(alert.tone == .critical)
        #expect(alert.label == "Agotado")
    }

    @Test("given a lot within 90 days of expiry, should be caution \"Por vencer\"")
    func expiringSoon() {
        let alert = ProductAlert.worst(lots: LotSummary(lots: [lot(expiresIn: 40), lot(expiresIn: 60)]), stockHere: 2, risk: .low)
        #expect(alert.tone == .caution)
        #expect(alert.label == "2 lotes por vencer")
    }

    @Test("given aging risk, should follow the risk level's tone and name",
          arguments: [(InventoryRiskLevel.medium, Tone.caution, "Riesgo medio"),
                      (.high, .critical, "Riesgo alto"), (.critical, .critical, "Riesgo crítico")])
    func aging(risk: InventoryRiskLevel, tone: Tone, label: String) {
        let alert = ProductAlert.worst(lots: LotSummary(lots: [lot()]), stockHere: 2, risk: risk)
        #expect(alert.tone == tone)
        #expect(alert.label == label)
    }

    @Test("given an expiring lot and critical aging risk, critical should win")
    func worstWins() {
        let alert = ProductAlert.worst(lots: LotSummary(lots: [lot(expiresIn: 40)]), stockHere: 2, risk: .high)
        #expect(alert.label == "Riesgo alto")
    }

    @Test("every alert should carry a glyph, so meaning isn't color alone")
    func glyph() {
        #expect(!ProductAlert.worst(lots: LotSummary(lots: []), stockHere: 2, risk: nil).systemImage.isEmpty)
    }
}
