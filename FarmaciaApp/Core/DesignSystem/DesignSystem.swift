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
//   - Money is ink (`MoneyText`, tabular digits); green means state, never
//     money. Healthy states are neutral; only problems escalate.
//   - No meaning by color alone: a tone also carries a glyph and words.
//   - Empty states are one 44pt `EmptyRow`, not a tall card.
//   (Full list: docs/inventory-ux-brief.md §7 "Detail screens".)
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
        case .positive: .accessibleGreen
        case .caution: .orange
        case .critical: .red
        case .info: .blue
        case .neutral: .secondary
        }
    }
}

extension Color {
    /// Text-safe green: `#0F7B3F` (5.35:1 on white) in light mode; systemGreen
    /// in dark, where it already clears 4.5:1. systemGreen on white is 2.22:1.
    static let accessibleGreen = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemGreen
            : UIColor(red: 0x0F / 255, green: 0x7B / 255, blue: 0x3F / 255, alpha: 1)
    })
}

// MARK: - Money Text
//
// Money is ink: primary color, tabular digits, cents set smaller than the
// whole part ("$220.00"). Green and red are for state, never for amounts.

struct MoneyText: View {
    let amount: Double
    var font: Font = .title
    var centsFont: Font = .title3

    var body: some View {
        let parts = ReportFormat.currencyParts(amount)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.symbol).font(centsFont)
            Text(parts.whole).font(font)
            Text(parts.fraction).font(centsFont)
        }
        .fontWeight(.bold)
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ReportFormat.currency(amount))
    }
}

// MARK: - Empty Row
//
// An empty state is one 44pt row, not a tall card: "Sin movimientos aún".

struct EmptyRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: DS.minTapSize, alignment: .leading)
            .padding(.horizontal)
            .background(Color(.systemGray6), in: .rect(cornerRadius: DS.Radius.xl))
    }
}
