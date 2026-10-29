import Foundation

// MARK: - Batch Source
//
// Where an inventory batch came from (InventoryReceiving.source on the API).

public enum BatchSource {
    public static func label(_ source: String?) -> String {
        switch source {
        case "PURCHASE": return "Compra"
        case "OPENING_BALANCE": return "Saldo Inicial"
        case "ADJUSTMENT": return "Ajuste"
        default: return source ?? "Desconocido"
        }
    }
}
