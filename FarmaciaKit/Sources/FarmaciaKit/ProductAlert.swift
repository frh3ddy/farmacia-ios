import Foundation

// MARK: - Product Alert
//
// The one chip on the product detail's Lotes block. Neutral unless something
// needs attention — a healthy product isn't green, it's quiet. The worst
// problem wins: expired lots, out of stock, high aging risk (critical), then
// lots near expiry and medium aging risk (caution). There's no "low stock":
// a fixed cutoff misfires on products that normally carry 1–2 units; that
// waits for per-product thresholds learned from history.
public struct ProductAlert: Equatable, Sendable {
    public let tone: Tone
    public let label: String
    public let systemImage: String

    public static func worst(lots: LotSummary, stockHere: Int, risk: InventoryRiskLevel?) -> ProductAlert {
        if lots.expired > 0 {
            return .init(tone: .critical, label: count(lots.expired, "vencido", "vencidos"), systemImage: "calendar.badge.exclamationmark")
        }
        if stockHere <= 0 {
            return .init(tone: .critical, label: "Agotado", systemImage: "xmark.circle")
        }
        if let risk, risk.tone == .critical {
            return aging(risk)
        }
        if lots.expiringSoon > 0 {
            return .init(tone: .caution, label: count(lots.expiringSoon, "por vencer", "por vencer"), systemImage: "calendar.badge.clock")
        }
        if let risk, risk.tone == .caution {
            return aging(risk)
        }
        return .init(tone: .neutral, label: "Sin alertas", systemImage: "checkmark")
    }

    private static func aging(_ risk: InventoryRiskLevel) -> ProductAlert {
        .init(tone: risk.tone, label: "Riesgo \(risk.displayName.lowercased())", systemImage: risk.icon)
    }

    private static func count(_ n: Int, _ one: String, _ many: String) -> String {
        n == 1 ? "1 lote \(one)" : "\(n) lotes \(many)"
    }
}
