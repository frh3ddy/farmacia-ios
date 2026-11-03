import Foundation

// MARK: - Inventory Risk Level
//
// Aging risk from GET /inventory/aging/* (`riskLevel` on a product, `severity` on a signal).
// Four levels on three tones: Alto and Crítico both need action (red); the icon and name
// still tell them apart.

public enum InventoryRiskLevel: String, Decodable, CaseIterable, Sendable {
    case low = "LOW"
    case medium = "MEDIUM"
    case high = "HIGH"
    case critical = "CRITICAL"

    public var displayName: String {
        switch self {
        case .low: "Bajo"
        case .medium: "Medio"
        case .high: "Alto"
        case .critical: "Crítico"
        }
    }

    public var icon: String {
        switch self {
        case .low: "checkmark.shield"
        case .medium: "exclamationmark.triangle"
        case .high: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    public var tone: Tone {
        switch self {
        case .low: .positive
        case .medium: .caution
        case .high, .critical: .critical
        }
    }

    /// Sort priority (lower = more severe = appears first)
    public var sortOrder: Int {
        switch self {
        case .critical: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }
}
