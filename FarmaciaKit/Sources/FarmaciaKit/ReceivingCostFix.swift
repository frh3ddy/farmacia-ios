import Foundation

// MARK: - Receiving Cost Fix (Corregir costo)
//
// The owner fixes a receiving saved with the wrong unit cost:
// POST /inventory/receive/:id/cost { unitCost } (OWNER only). The API recosts the
// receiving, its batch and lots, past sales and losses from it, and the supplier's
// current cost if it's that supplier's latest receiving. It refuses (409, a message
// to show as-is) when units already moved on: transferred, opened, sold and returned.
// Not queued offline (`OfflineReplay`): a late replay could land after those moves.

public enum ReceivingCostFix {
    public static let failure = "No se pudo corregir el costo"

    /// Matches the API's @Roles('OWNER').
    public static func canFix(isOwner: Bool) -> Bool {
        isOwner
    }

    /// The typed cost, exact (Decimal): a number ≥ 0, with "." or "," as decimal separator.
    public static func cost(from text: String) -> Decimal? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        // Decimal(string:) stops at the first bad character ("26.7.1" → 26.7), so check the whole text.
        guard !normalized.isEmpty, normalized.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              normalized.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: normalized, locale: posix) else { return nil }
        return value
    }

    /// Guardar: a valid cost that changes the receiving's (`oldCost`: the API's decimal string).
    public static func canSave(newCost: Decimal?, oldCost: String) -> Bool {
        guard let newCost else { return false }
        return newCost != Decimal(string: oldCost, locale: posix)
    }

    /// "$30.00 → $26.71", for the sheet and the confirmation.
    public static func comparison(oldCost: String, newCost: Decimal) -> String {
        "\(ReportFormat.currency(oldCost)) → \(ReportFormat.currency("\(newCost)"))"
    }

    public struct Request: Encodable, Equatable, Sendable {
        public let unitCost: Decimal

        public init(unitCost: Decimal) {
            self.unitCost = unitCost
        }
    }

    private static let posix = Locale(identifier: "en_US_POSIX")
}
