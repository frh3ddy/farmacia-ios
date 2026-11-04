import Foundation

// MARK: - Receiving Form

public enum ReceivingForm {
    /// What's missing, top to bottom as the form lays it out. The button stays
    /// on; after a tap these show under their fields and focus goes to the first.
    public enum Issue: Hashable, Sendable {
        case quantity, cost, price

        public var message: String {
            switch self {
            case .quantity: "Indica cuántas recibiste"
            case .cost: "Indica el costo unitario (0 si fue regalo)"
            case .price: "Indica el nuevo precio"
            }
        }

        var noun: String {
            switch self {
            case .quantity: "cantidad"
            case .cost: "costo"
            case .price: "precio"
            }
        }
    }

    /// At least one unit and a cost (zero is allowed: free goods). With
    /// "Cambiar precio" on, also a positive price; otherwise the receiving
    /// would save without the price the user asked for.
    public static func issues(quantity: Int?, unitCost: Double?, updatesPrice: Bool, newPrice: Double?) -> [Issue] {
        var issues: [Issue] = []
        if (quantity ?? 0) <= 0 { issues.append(.quantity) }
        if (unitCost ?? -1) < 0 { issues.append(.cost) }
        if updatesPrice, (newPrice ?? 0) <= 0 { issues.append(.price) }
        return issues
    }

    public static func canSave(quantity: Int?, unitCost: Double?, updatesPrice: Bool, newPrice: Double?) -> Bool {
        issues(quantity: quantity, unitCost: unitCost, updatesPrice: updatesPrice, newPrice: newPrice).isEmpty
    }

    /// The line above the button after a failed tap: "Falta cantidad y costo".
    public static func summary(_ issues: [Issue]) -> String? {
        let nouns = issues.map(\.noun)
        guard let last = nouns.last else { return nil }
        let list = nouns.count == 1 ? last : nouns.dropLast().joined(separator: ", ") + " y " + last
        return "Falta " + list
    }
}
