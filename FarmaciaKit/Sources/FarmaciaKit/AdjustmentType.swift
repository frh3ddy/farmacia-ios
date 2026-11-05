import Foundation

// MARK: - Adjustment Type

public enum AdjustmentType: String, Codable, Identifiable, Sendable {
    public var id: String { rawValue }

    case damage = "DAMAGE"
    case theft = "THEFT"
    case expired = "EXPIRED"
    case countCorrection = "COUNT_CORRECTION"
    /// Conteo inicial: fixes stock the migration loaded wrong; out of shrinkage and the P&L.
    case openingCount = "OPENING_COUNT"
    case found = "FOUND"
    case returnType = "RETURN"
    case transferOut = "TRANSFER_OUT"
    case transferIn = "TRANSFER_IN"
    case writeOff = "WRITE_OFF"
    case other = "OTHER"
    case breakBulkOut = "BREAK_BULK_OUT"
    case breakBulkIn = "BREAK_BULK_IN"
    case autoSaleCover = "AUTO_SALE_COVER"
    /// A type this build doesn't know (from a newer server).
    case unknown = "UNKNOWN"

    /// A type this build doesn't know decodes as `.unknown` instead of failing the whole list.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AdjustmentType(rawValue: raw) ?? .unknown
    }

    public var displayName: String {
        switch self {
        case .damage: "Daño"
        case .theft: "Robo"
        case .expired: "Vencido"
        case .countCorrection: "Corrección de Conteo"
        case .openingCount: "Conteo inicial"
        case .found: "Encontrado"
        case .returnType: "Devolución"
        case .transferOut: "Transferencia Salida"
        case .transferIn: "Transferencia Entrada"
        case .writeOff: "Baja"
        case .other: "Otro"
        case .breakBulkOut: "Desglose (Caja)"
        case .breakBulkIn: "Desglose (Piezas Sueltas)"
        case .autoSaleCover: "Cobertura Automática de Venta"
        case .unknown: "Ajuste"
        }
    }

    /// Spanish name for a raw server type ("DAMAGE" → "Daño"); unknown types pass through.
    public static func label(_ raw: String) -> String {
        AdjustmentType(rawValue: raw)?.displayName ?? raw
    }

    public var isNegative: Bool {
        switch self {
        case .damage, .theft, .expired, .transferOut, .writeOff, .breakBulkOut: true
        default: false
        }
    }

    /// Entered as a total counted (or, for Otro, a signed change) rather than a quantity.
    public var isVariable: Bool {
        switch self {
        case .countCorrection, .openingCount, .other: true
        default: false
        }
    }
}
