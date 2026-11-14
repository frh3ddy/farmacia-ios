import Foundation

// MARK: - Alertas lists
//
// GET /products?filter=outAlert|lowAlert (stock alerts O6): only regular sellers that
// aren't paused, highest lost sales a day first, paged like every other list.

public enum AlertList: String, CaseIterable, Sendable {
    case out = "Sin Stock"
    case low = "Stock Bajo"
    case lowMargin = "Margen Bajo"

    var apiFilter: String {
        switch self {
        case .out: "outAlert"
        case .low: "lowAlert"
        case .lowMargin: "lowMargin"
        }
    }

    /// Why this list's count differs from the Productos chip of the same name.
    public var note: String? {
        switch self {
        case .out: "Solo productos que se venden seguido y no están pausados. Primero los que más ventas pierden."
        case .low: "Solo productos que se venden seguido y no están pausados. Primero los que se acaban antes."
        case .lowMargin: nil
        }
    }

    /// The list's count; Sin Stock falls back to every product at 0 on an older server.
    public func count(_ counts: ProductCountsResponse) -> Int? {
        switch self {
        case .out: counts.outAlert ?? counts.outOfStock
        case .low: counts.lowStock
        case .lowMargin: counts.lowMargin
        }
    }

    /// Whether a row updated from the detail (paused, restocked) still belongs in this list.
    public func keeps(_ alert: StockAlert?) -> Bool {
        switch self {
        case .out: alert?.level == .out
        case .low: alert?.level == .low
        case .lowMargin: true
        }
    }

    /// Margen Bajo comes from cost, which a cashier never sees.
    public static func visible(canViewCosts: Bool) -> [AlertList] {
        allCases.filter { canViewCosts || $0 != .lowMargin }
    }
}

extension StockAlert {
    /// Why an Alertas row matters, e.g. "Vende ~1 al día · alcanza para ~4 días"; an out row's
    /// badge already says since when. `priority` is units a day for out, units a day ÷ on hand for low.
    public func reasonText(quantity: Int) -> String? {
        guard priority > 0 else { return nil }
        switch level {
        case .none:
            return nil
        case .out:
            return Self.rateText(rate ?? priority)
        case .low:
            let days = 1 / priority
            let lasts = days < 1 ? "menos de 1 día" : (days.rounded() == 1 ? "~1 día" : "~\(Int(days.rounded())) días")
            return "\(Self.rateText(rate ?? priority * Double(max(quantity, 1)))) · alcanza para \(lasts)"
        }
    }

    /// The product detail's sales line, e.g. "Vende ~1 al día · última venta hace 2 días": the
    /// same rate and wording as Alertas' reason. Nil without stats (older server, new product).
    public func salesLine(now: Date = Date(), timeZone: TimeZone = .current) -> String? {
        guard let rate else { return nil }
        let last = lastSoldAt.map { "última venta \(DisplayDate.relative($0, now: now, timeZone: timeZone))" }
        guard rate > 0 else { return last.map { "Sin ventas recientes · \($0)" } ?? "Sin ventas registradas" }
        return [Self.rateText(rate), last].compactMap { $0 }.joined(separator: " · ")
    }

    private static func rateText(_ perDay: Double) -> String {
        if perDay >= 1 { return "Vende ~\(Int(perDay.rounded())) al día" }
        if perDay * 7 >= 1 { return "Vende ~\(Int((perDay * 7).rounded())) a la semana" }
        return "Vende ~\(max(1, Int((perDay * 30).rounded()))) al mes"
    }
}
