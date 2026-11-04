import SwiftUI
import FarmaciaKit

// MARK: - Margin Chips
//
// Header: the resulting margin ("40% · ganas $8.00") and, while a chip is
// applied, a ⊗ that releases it — the price stays, now as a manual price.
// The release lives inside the control it affects, so it costs no layout.

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
    /// The margin and profit per unit at the current price and cost, if any.
    let result: (margin: Double, profit: Double)?
    /// Drop the applied margin, keep the price.
    let onRelease: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : options.count + 1
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s), count: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            header
            grid
        }
    }

    private var header: some View {
        LabeledContent("Margen") {
            if let result {
                HStack(spacing: DS.Spacing.xs) {
                    Text("\(Int(result.margin.rounded()))% · ganas \(result.profit.mxn)")
                        .monospacedDigit()
                        .foregroundStyle(Margin.tone(forPercent: result.margin).color)
                    if selected != nil {
                        Button("Quitar margen", systemImage: "xmark.circle.fill", action: onRelease)
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .buttonStyle(.borderless)
                            .accessibilityHint("El precio se queda como precio fijo")
                    }
                }
            } else {
                Text("Elige uno para sugerir precio")
                    .font(.footnote)
            }
        }
    }

    private var grid: some View {
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
