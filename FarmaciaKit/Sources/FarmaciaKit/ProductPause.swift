import Foundation

// MARK: - Product Pause
//
// POST /products/:id/pause and DELETE /products/:id/pause?locationId= (stock alerts O5),
// owner/manager only, at the session's store. Both answer the product's updated row.

public struct PauseRequest: Encodable, Equatable, Sendable {
    public let locationId: String
    public let reason: PauseReason
    public let note: String?
    /// Only with `.replacedByEquivalent`: the product sold instead.
    public let replacedByProductId: String?
}

/// The Pausar sheet's rules, worded like the API's refusals.
public enum PauseForm {
    public enum Check: Equatable, Sendable {
        case send(PauseRequest)
        case fail(String)
    }

    public enum Action: Equatable, Sendable { case pause, resume }

    static let noteMax = 500

    public static func validate(productId: String, locationId: String, reason: PauseReason?, replacementId: String?, note: String) -> Check {
        guard let reason else { return .fail("Elige un motivo") }
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard note.count <= noteMax else { return .fail("La nota debe tener hasta \(noteMax) caracteres") }
        var replacement: String?
        if reason.requiresProduct {
            guard let replacementId else { return .fail("Elige el producto que lo reemplaza") }
            guard replacementId != productId else { return .fail("Un producto no puede reemplazarse a sí mismo") }
            replacement = replacementId
        }
        return .send(PauseRequest(locationId: locationId, reason: reason, note: note.isEmpty ? nil : note, replacedByProductId: replacement))
    }

    /// What the Ajustar menu offers, if anything. No alert means an old server without pausing.
    /// Pausing needs a product this store stocks (the API refuses the rest); resuming is always allowed.
    public static func action(alert: StockAlert?, isManager: Bool, tracksInventory: Bool?, soldOnlyAtLocationId: String?, currentLocationId: String?) -> Action? {
        guard isManager, let alert else { return nil }
        if alert.paused { return .resume }
        guard tracksInventory != false,
              StockEntry.canAdd(soldOnlyAtLocationId: soldOnlyAtLocationId, currentLocationId: currentLocationId) else { return nil }
        return .pause
    }
}

extension StockLevel {
    /// The line under the product detail's stock number: Pausado (with its reason) wins over Agotado.
    public var detailText: String? {
        switch self {
        case .paused: label
        case .out, .empty: "Agotado en esta tienda"
        default: nil
        }
    }
}
