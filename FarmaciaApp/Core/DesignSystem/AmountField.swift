import SwiftUI
import FarmaciaKit

// MARK: - Amount Field
//
// The form row for prices, costs and quantities: optional label, "$" prefix,
// the number, a unit ("MXN", "UDS"). Replaces the hand-built HStack each form
// repeated.
//   - Tapping anywhere on the row focuses the field; the row is at least 44pt.
//   - Backed by text, read on every keystroke (`AmountText`), so the form's
//     Crear/Guardar enables while typing. A value set from elsewhere (e.g. a
//     prefilled supplier cost) still shows up in the field.

struct AmountField<Field: Hashable>: View {
    private let label: String?
    private let placeholder: String
    private let prefix: String?
    private let unit: String?
    private let keyboard: UIKeyboardType
    @Binding private var value: Double?
    private let focus: FocusState<Field?>.Binding
    private let field: Field

    @State private var text = ""

    /// A money amount (decimal pad).
    init(
        _ label: String? = nil,
        placeholder: String = "0.00",
        prefix: String? = nil,
        unit: String? = nil,
        value: Binding<Double?>,
        focus: FocusState<Field?>.Binding,
        field: Field
    ) {
        self.label = label
        self.placeholder = placeholder
        self.prefix = prefix
        self.unit = unit
        self.keyboard = .decimalPad
        self._value = value
        self.focus = focus
        self.field = field
    }

    /// A whole-number quantity (number pad).
    init(
        _ label: String? = nil,
        placeholder: String = "0",
        unit: String? = nil,
        quantity: Binding<Int?>,
        focus: FocusState<Field?>.Binding,
        field: Field
    ) {
        self.label = label
        self.placeholder = placeholder
        self.prefix = nil
        self.unit = unit
        self.keyboard = .numberPad
        self._value = Binding(
            get: { quantity.wrappedValue.map(Double.init) },
            set: { quantity.wrappedValue = $0.map { Int($0) } }
        )
        self.focus = focus
        self.field = field
    }

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            if let label {
                Text(label)
            }
            if let prefix {
                Text(prefix)
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .multilineTextAlignment(label == nil ? .leading : .trailing)
                .focused(focus, equals: field)
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: DS.minTapSize)
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = field }
        .onChange(of: text) { _, newText in
            value = AmountText.parse(newText)
        }
        .onChange(of: value, initial: true) { _, newValue in
            // Only rewrite the text for changes made elsewhere; while typing,
            // "12." already parses to the same value and stays as typed.
            if AmountText.parse(text) != newValue {
                text = AmountText.string(from: newValue)
            }
        }
    }
}
