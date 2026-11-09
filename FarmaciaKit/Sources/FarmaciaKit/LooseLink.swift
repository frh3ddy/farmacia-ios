import Foundation

// MARK: - Loose Link (Sueltos)
//
// PATCH /products/:id/loose-link: links a box product to its suelto at the
// session's store. `quantity` (piezas por caja) lives on the box, same at every store.

public struct LooseLinkRequest: Encodable, Equatable, Sendable {
    public let looseProductId: String?
    public let quantity: Int?

    public init(looseProductId: String?, quantity: Int?) {
        self.looseProductId = looseProductId
        self.quantity = quantity
    }

    public static let unlink = LooseLinkRequest(looseProductId: nil, quantity: nil)

    private enum CodingKeys: String, CodingKey { case looseProductId, quantity }

    /// Always sends `looseProductId`: the API unlinks only on an explicit null; a
    /// missing key (what synthesized Encodable writes for nil) leaves the link as is.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(looseProductId, forKey: .looseProductId)
        try container.encodeIfPresent(quantity, forKey: .quantity)
    }
}

/// The "Vincular caja con suelto" form's rules, worded like the web (BreakBulkScreen.tsx).
public enum LooseLinkForm {
    public enum Check: Equatable, Sendable {
        case send(LooseLinkRequest)
        case fail(String)
    }

    /// The request to send, or why not. `quantity` is sent only when it changes the box's.
    public static func validate(boxId: String?, boxQuantity: Int?, sueltoId: String?, quantityText: String) -> Check {
        guard let boxId, let sueltoId else { return .fail("Elige el producto de caja y el producto suelto") }
        guard boxId != sueltoId else { return .fail("Un producto no puede ser su propio producto suelto") }
        let text = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            guard boxQuantity != nil else { return .fail("Este producto no tiene cantidad (piezas por caja) — indícala") }
            return .send(LooseLinkRequest(looseProductId: sueltoId, quantity: nil))
        }
        guard let quantity = Int(text), quantity > 0 else {
            return .fail("La cantidad debe ser un número entero mayor que cero")
        }
        return .send(LooseLinkRequest(looseProductId: sueltoId, quantity: quantity == boxQuantity ? nil : quantity))
    }

    public static func prefill(boxQuantity: Int?) -> String {
        boxQuantity.map(String.init) ?? ""
    }

    /// A search row's hint; `linked` means linked at this store (the API resolves it per store).
    public static func pickerSubtitle(sku: String?, quantity: Int?, linked: Bool) -> String {
        var parts = [sku.map { "SKU \($0)" } ?? "Sin SKU"]
        if let quantity { parts.append("cantidad \(quantity)") }
        if linked { parts.append("ya vinculado") }
        return parts.joined(separator: " · ")
    }

    public static func linkedText(box: String, suelto: String, store: String) -> String {
        "\"\(box)\" vinculado con \"\(suelto)\" en \(store)."
    }

    public static func unlinkedText(box: String, store: String) -> String {
        "\"\(box)\" desvinculado en \(store)."
    }
}
