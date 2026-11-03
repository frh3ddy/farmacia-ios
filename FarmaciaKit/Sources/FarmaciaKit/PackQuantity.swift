import Foundation

// MARK: - Pack Quantity
//
// Receiving by the box: the form multiplies Cajas × Piezas por caja into
// Cantidad (units are what the API stores).

public enum PackQuantity {
    /// nil until both sides are positive.
    public static func total(boxes: Int?, perBox: Int?) -> Int? {
        guard let boxes, let perBox, boxes > 0, perBox > 0 else { return nil }
        return boxes * perBox
    }
}
