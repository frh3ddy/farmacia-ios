import SwiftUI
import FarmaciaKit

// MARK: - Design System
//
// Three layers (the /design-system skill's model, written in Swift):
//   1. Raw values — SwiftUI's system colors and the numbers below. These are
//      the values the app already used; nothing here changes how it looks.
//   2. Purpose — `DS.Spacing`, `DS.Radius`, `Tone.color`. Screens use these.
//   3. Components — `AmountField`, `.formKeyboard(…)`, built from layer 2.
//
// Rules (swiftui-pro design guidance):
//   - Text uses built-in text styles (`.body`, `.subheadline`, `.caption`…), never
//     fixed point sizes, so Dynamic Type works.
//   - Anything tappable is at least `DS.minTapSize` tall.
//   - Meaning picks the color: a rule in FarmaciaKit returns a `Tone`, the view
//     shows `tone.color`. Screens don't choose green/orange/red themselves.
//
// Screens move onto this as they're touched (pilots: CreateProductView,
// ReceiveInventoryFormView — tasks/design-system-epic.md).

enum DS {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    enum Radius {
        /// Small badges and tags.
        static let s: CGFloat = 4
        /// Thumbnails and chips.
        static let m: CGFloat = 8
        /// Cards.
        static let l: CGFloat = 12
        /// Large tiles (e.g. the product photo).
        static let xl: CGFloat = 16
    }

    /// Apple's minimum tap target.
    static let minTapSize: CGFloat = 44
}

extension Tone {
    var color: Color {
        switch self {
        case .positive: .green
        case .caution: .orange
        case .critical: .red
        case .info: .blue
        case .neutral: .secondary
        }
    }
}
