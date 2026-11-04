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

struct AmountField<Field: Hashable, Value: AmountValue>: View {
    private let label: String?
    private let prefix: String?
    private let unit: String?
    @Binding private var value: Value?
    private let focus: FocusState<Field?>.Binding
    private let field: Field
    private let alignment: TextAlignment?

    @State private var text = ""

    /// Money (`Double`, decimal pad) or a whole-number quantity (`Int`, number pad).
    init(
        _ label: String? = nil,
        prefix: String? = nil,
        unit: String? = nil,
        value: Binding<Value?>,
        focus: FocusState<Field?>.Binding,
        field: Field,
        alignment: TextAlignment? = nil
    ) {
        self.label = label
        self.prefix = prefix
        self.unit = unit
        self._value = value
        self.focus = focus
        self.field = field
        self.alignment = alignment
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
            TextField(Value.placeholder, text: $text)
                .keyboardType(Value.keyboard)
                .multilineTextAlignment(alignment ?? (label == nil ? .leading : .trailing))
                .focused(focus, equals: field)
            if let unit {
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: DS.minTapSize)
        .contentShape(.rect)
        .onTapGesture { focus.wrappedValue = field }
        .id(field)  // .formKeyboard scrolls the focused row into place
        .onChange(of: text) { _, newText in
            value = Value(parsing: newText)
        }
        .onChange(of: value, initial: true) { _, newValue in
            // Only rewrite the text for changes made elsewhere; while typing,
            // "12." already parses to the same value and stays as typed.
            if Value(parsing: text) != newValue {
                text = AmountText.string(from: newValue?.amount)
            }
        }
    }
}
