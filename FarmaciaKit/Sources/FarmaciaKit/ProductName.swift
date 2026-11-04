import Foundation

// MARK: - Product Name
//
// `name` is the API's full name ("Item (Variation)", catalog.service.ts), `item` and
// `variation` are Square's item and variation names. `display` is the short name the
// list rows have always shown; `full` tells an item's variations apart (cards).

public enum ProductName {
    /// Square item name, then variation name, then `name` — skipping blank and "no variation" names.
    public static func display(name: String, item: String?, variation: String?) -> String {
        clean(item) ?? clean(variation) ?? name
    }

    /// "Item (Variation)", unless the variation is a placeholder or already in the item name.
    public static func full(name: String, item: String?, variation: String?) -> String {
        guard let item = clean(item) else { return display(name: name, item: item, variation: variation) }
        guard let variation = clean(variation),
              !placeholders.contains(variation.lowercased()),
              !item.localizedCaseInsensitiveContains(variation)
        else { return item }
        return "\(item) (\(variation))"
    }

    /// The API's PLACEHOLDER_NAMES (catalog.service.ts).
    private static let placeholders: Set<String> = ["regular", "sin variación", "sin variacion", "no variation", "unknown"]

    /// Trimmed, or nil when blank or a "no variation" name (the old `displayName` rule).
    private static func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        let lower = s.lowercased()
        return lower.contains("sin variaci") || lower.contains("no variation") ? nil : s
    }
}

// MARK: - Length hint
//
// No hard limit (the API has none), but Square POS and receipts show about 32
// characters: a counter appears near that, and a caution past it.

extension ProductName {
    public static let receiptLength = 32

    public struct LengthHint: Equatable, Sendable {
        public let text: String
        public let tone: Tone
    }

    public static func lengthHint(_ name: String) -> LengthHint? {
        let count = name.trimmingCharacters(in: .whitespacesAndNewlines).count
        guard count >= receiptLength - 4 else { return nil }
        let counter = "\(count)/\(receiptLength)"
        guard count > receiptLength else { return LengthHint(text: counter, tone: .neutral) }
        return LengthHint(text: counter + " · Square POS y los tickets muestran ~\(receiptLength) caracteres", tone: .caution)
    }
}
