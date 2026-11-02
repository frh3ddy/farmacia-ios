import Foundation

// MARK: - Focus Order
//
// The order a form's text fields are visited by the keyboard toolbar's ‹ ›
// and the return key. Build it per render from the fields currently shown, so
// a hidden row (e.g. initial stock switched off) is simply skipped.

public struct FocusOrder<Field: Hashable> {
    public let fields: [Field]

    public init(_ fields: [Field]) {
        self.fields = fields
    }

    /// The field after `field`, or nil at the end (the keyboard closes).
    public func next(after field: Field) -> Field? {
        guard let index = fields.firstIndex(of: field), index + 1 < fields.count else { return nil }
        return fields[index + 1]
    }

    /// The field before `field`, or nil at the start.
    public func previous(before field: Field) -> Field? {
        guard let index = fields.firstIndex(of: field), index > 0 else { return nil }
        return fields[index - 1]
    }
}
