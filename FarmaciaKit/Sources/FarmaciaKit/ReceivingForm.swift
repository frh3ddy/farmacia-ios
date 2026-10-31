import Foundation

// MARK: - Receiving Form

public enum ReceivingForm {
    /// Guardar needs at least one unit and a cost (zero is allowed: free goods).
    /// With "Actualizar Precio de Venta" on it also needs a positive price;
    /// otherwise the receiving would save without the price the user asked for.
    public static func canSave(quantity: Int?, unitCost: Double?, updatesPrice: Bool, newPrice: Double?) -> Bool {
        guard (quantity ?? 0) > 0, (unitCost ?? -1) >= 0 else { return false }
        return !updatesPrice || (newPrice ?? 0) > 0
    }
}
