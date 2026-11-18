import Foundation

// MARK: - Recent receiving (Recibir)
//
// A product already received at this store today or yesterday: a warning at the
// top of Recibir, so a delivery isn't entered twice. From the server's history
// (GET /inventory/receive/product/:id), so it survives closing the scanner and
// covers a receiving made on another phone. A warning, not a block: a second
// lot of the same product is normal.

public enum RecentReceiving {
    public struct Row: Equatable, Sendable {
        public let receivedAt: Date
        public let quantity: Int
        public let locationId: String
        public let supplierName: String?

        public init(receivedAt: Date, quantity: Int, locationId: String, supplierName: String?) {
            self.receivedAt = receivedAt
            self.quantity = quantity
            self.locationId = locationId
            self.supplierName = supplierName
        }
    }

    /// `rows` newest first, as the API returns them; nil when they couldn't be loaded.
    public static func note(_ rows: [Row]?, locationId: String, now: Date = Date(), timeZone: TimeZone = .current) -> String? {
        guard let rows else { return "No se pudo revisar si ya se recibió hoy o ayer." }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let since = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else { return nil }
        let recent = rows.filter { $0.locationId == locationId && $0.receivedAt >= since }
        guard let latest = recent.first else { return nil }

        let day = DisplayDate.relative(latest.receivedAt, now: now, timeZone: timeZone)
        let at = calendar.component(.hour, from: latest.receivedAt) % 12 == 1 ? "a la" : "a las"
        let time = DisplayDate.time(latest.receivedAt, timeZone: timeZone)
        let supplier = latest.supplierName.map { " (\($0))" } ?? ""
        let when = "\(day) \(at) \(time)\(supplier)"
        let what = recent.count == 1
            ? "Ya se \(latest.quantity == 1 ? "recibió" : "recibieron") \(units(latest.quantity)) \(when)"
            : "Ya se recibió \(recent.count) veces \(recent.allSatisfy { calendar.isDate($0.receivedAt, inSameDayAs: now) } ? "hoy" : "desde ayer") (\(units(recent.reduce(0) { $0 + $1.quantity }))); la última \(when)"
        // "p.m." already ends the sentence.
        return what + (what.hasSuffix(".") ? " " : ". ") + "Revisa antes de recibir otra vez."
    }

    private static func units(_ quantity: Int) -> String {
        quantity == 1 ? "1 ud" : "\(quantity) uds"
    }
}
