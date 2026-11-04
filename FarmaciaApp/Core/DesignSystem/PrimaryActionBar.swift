import SwiftUI
import FarmaciaKit

// MARK: - Primary Action Bar
//
// One full-width action at the bottom of a form (tasks/inventory-forms-redesign-epic.md):
// always enabled, label never changes; a summary line above it ("12 uds × $17.90 ·
// Total $214.80", or what's missing after a failed tap). Spinner while saving, a
// checkmark once done. The inventory forms also share `.fieldError`,
// `QuantityStepper`, `MarginChips` and `OptionalHeader`.

extension Double {
    /// "$1,234.50" — the system caches format styles, unlike a NumberFormatter per call.
    var mxn: String {
        formatted(.currency(code: "MXN").locale(Locale(identifier: "es_MX")))
    }
}

struct PrimaryActionBar: View {
    let title: String
    /// Shown with a checkmark for a moment after it worked, before the sheet closes.
    let doneTitle: String
    /// "12 uds × $17.90 · Total $214.80", or what's missing after a failed tap.
    var summary: String?
    var summaryTone: Tone = .neutral
    let isSubmitting: Bool
    let isDone: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            if let summary {
                Text(summary)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(summaryTone == .neutral ? .secondary : summaryTone.color)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }

            Button(action: action) {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel("Guardando")
                    } else if isDone {
                        Label(doneTitle, systemImage: "checkmark")
                    } else {
                        Text(title)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: DS.minTapSize)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .buttonBorderShape(.roundedRectangle(radius: DS.Radius.l))
            // Not .disabled: it would grey out while saving. Taps are ignored instead.
            .allowsHitTesting(!isSubmitting && !isDone)
            .sensoryFeedback(.success, trigger: isDone) { _, done in done }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.s)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .animation(.default, value: summary)
    }
}

extension View {
    /// Pins `bar` to the bottom, and lets the form scroll clear of it. While the
    /// keyboard is up the bar fades out (it would otherwise ride up with the
    /// keyboard and cover the focused field); its space stays reserved, so
    /// nothing in the form moves — see `.formKeyboard`.
    func primaryActionBar(_ bar: PrimaryActionBar) -> some View {
        modifier(PrimaryActionBarModifier(bar: bar))
    }
}

private struct PrimaryActionBarModifier: ViewModifier {
    let bar: PrimaryActionBar
    @State private var height: CGFloat = 0
    @State private var keyboardUp = false

    func body(content: Content) -> some View {
        content
            // The bar's height plus breathing room, so the last field (Notas,
            // Descripción) doesn't sit flush against the bar.
            .contentMargins(.bottom, height + DS.Spacing.xxl, for: .scrollContent)
            .overlay(alignment: .bottom) {
                bar
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                    .opacity(keyboardUp ? 0 : 1)
                    .allowsHitTesting(!keyboardUp)
                    .accessibilityHidden(keyboardUp)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                withAnimation(.keyboard(note)) { keyboardUp = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
                withAnimation(.keyboard(note)) { keyboardUp = false }
            }
    }
}

// MARK: - Previews

#Preview("Form controls") {
    @Previewable @State var qty: Int? = 12
    @Previewable @State var pick: Double? = 40
    @Previewable @FocusState var focus: Int?
    Form {
        QuantityStepper(value: $qty, unit: "unidades", focus: $focus, field: 0)
        MarginChips(
            options: PriceSuggestion.chips.map { .init(label: "\(Int($0))%", margin: $0, price: PriceSuggestion.price(cost: 12, marginPercent: $0)) },
            selected: pick,
            onSelect: { pick = $0 },
            onOther: { pick = nil },
            result: (40, 8),
            onRelease: { pick = nil }
        )
        Text("Costo").fieldError("Indica el costo unitario (0 si fue regalo)", shake: 1, field: 1)
    }
    .primaryActionBar(PrimaryActionBar(
        title: "Recibir inventario", doneTitle: "Inventario recibido",
        summary: "12 uds × $17.90 · Total $214.80", isSubmitting: false, isDone: false, action: {}
    ))
}
