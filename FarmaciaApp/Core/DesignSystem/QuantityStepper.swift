import SwiftUI
import FarmaciaKit

// MARK: - Quantity Stepper

/// The hero quantity: big centered number (typeable), −/+ either side.
struct QuantityStepper<Field: Hashable>: View {
    @Binding var value: Int?
    /// Under the number: "unidades", "cajas".
    let unit: String
    let focus: FocusState<Field?>.Binding
    let field: Field

    /// ± taps only: typing, or Unidades/Cajas swapping the bound value, stays silent.
    @State private var ups = 0
    @State private var downs = 0

    private var current: Int { value ?? 0 }

    var body: some View {
        HStack(spacing: DS.Spacing.l) {
            stepButton("Restar uno", systemImage: "minus") {
                value = max(0, current - 1)
                downs += 1
            }
                .disabled(current <= 0)

            VStack(spacing: 0) {
                AmountField(value: $value, focus: focus, field: field, alignment: .center)
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .accessibilityLabel("Cantidad en \(unit)")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: value = current + 1
                        case .decrement: value = max(0, current - 1)
                        @unknown default: break
                        }
                    }
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            stepButton("Sumar uno", systemImage: "plus") {
                value = current + 1
                ups += 1
            }
        }
        .sensoryFeedback(.increase, trigger: ups)
        .sensoryFeedback(.decrease, trigger: downs)
        .padding(.vertical, DS.Spacing.s)
    }

    private func stepButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .font(.title2.weight(.semibold))
            .frame(width: 48, height: 48)
            .background(.fill.secondary, in: .circle)
            .buttonStyle(.borderless)
            .buttonRepeatBehavior(.enabled)
    }
}
