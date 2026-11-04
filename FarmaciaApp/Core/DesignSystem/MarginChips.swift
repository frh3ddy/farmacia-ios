import SwiftUI
import FarmaciaKit

// MARK: - Margin Chips

struct MarginChips: View {
    struct Option: Identifiable {
        /// "Actual", "30%"…
        let label: String
        let margin: Double
        let price: Double?
        var id: String { label }
    }

    let options: [Option]
    /// The picked margin (`MarginPick.selected`).
    let selected: Double?
    let onSelect: (Double) -> Void
    /// "Otro": the user types the price.
    let onOther: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : options.count + 1
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.s) {
            ForEach(options) { option in
                chip(option.label, detail: option.price?.mxn, isSelected: option.margin == selected) {
                    onSelect(option.margin)
                }
                .disabled(option.price == nil)
            }
            chip("Otro", detail: nil, isSelected: false, action: onOther)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func chip(_ title: String, detail: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .monospacedDigit()
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: DS.minTapSize)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                        in: .rect(cornerRadius: DS.Radius.m))
            .contentShape(.rect)
        }
        // .plain, not .borderless: borderless tints the label, so every chip
        // read as selected. Each chip still takes its own taps inside a Form row.
        .buttonStyle(.plain)
        .accessibilityLabel(detail.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
