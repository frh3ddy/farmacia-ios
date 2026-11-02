import SwiftUI
import FarmaciaKit

// MARK: - Form Keyboard
//
// One modifier for how every form's keyboard behaves:
//   - A toolbar above the keyboard: ‹ › walk the fields in `order`, Listo closes
//     the keyboard. The number pad has no return key, so without this the
//     only way out was tapping elsewhere. The bar also gives the focused field
//     native breathing room above the keys (no extra inset needed).
//   - The return key moves to the next field; on the last one it closes.
//   - Scrolling closes the keyboard immediately (`.immediately`, not
//     `.interactively`: interactive dismissal leaves the safe area stale
//     mid-drag, and a scrolled-away focused field yanks the form back on the
//     next tap).
//
// Replaces the app-wide tap-outside detector (a UIKit recognizer on every
// window) — it closed the keyboard on the same tap aimed at a button, shifting
// the form mid-tap.

extension View {
    func formKeyboard<Field: Hashable>(
        focus: FocusState<Field?>.Binding,
        order: FocusOrder<Field>
    ) -> some View {
        modifier(FormKeyboardModifier(focus: focus, order: order))
    }
}

private struct FormKeyboardModifier<Field: Hashable>: ViewModifier {
    var focus: FocusState<Field?>.Binding
    let order: FocusOrder<Field>

    private var previous: Field? { focus.wrappedValue.flatMap(order.previous(before:)) }
    private var next: Field? { focus.wrappedValue.flatMap(order.next(after:)) }

    func body(content: Content) -> some View {
        content
            .submitLabel(.next)
            .onSubmit { focus.wrappedValue = next }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Campo anterior", systemImage: "chevron.up") {
                        focus.wrappedValue = previous
                    }
                    .disabled(previous == nil)

                    Button("Campo siguiente", systemImage: "chevron.down") {
                        focus.wrappedValue = next
                    }
                    .disabled(next == nil)

                    Spacer()

                    Button("Listo") { focus.wrappedValue = nil }
                        .bold()
                }
            }
            .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Keyboard-Top Spacing
//
// SwiftUI already scrolls the focused field above the keyboard, but leaves it
// flush against the keyboard's top edge. This modifier adds a small extra
// gap so bottom fields stay visually separated and more visible while editing.
//
// Driven by `@FocusState` (passed in as `isActive`) rather than by observing
// `keyboardWillShowNotification`: focus changes land in the same view-update
// pass as Form's own "scroll focused field into view" adjustment, so the
// extra spacing is applied together with that scroll instead of growing the
// safe-area inset afterward and forcing a second, visibly delayed rescroll.

private struct KeyboardTopSpacingModifier: ViewModifier {
    let spacing: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: isActive ? spacing : 0)
            }
            .animation(.easeOut(duration: 0.25), value: isActive)
    }
}

extension View {
    /// Extra breathing room between the keyboard's top edge and this view's
    /// bottom edge while `isActive` (typically `focusedField != nil`) is true.
    func keyboardTopSpacing(_ spacing: CGFloat = 20, isActive: Bool) -> some View {
        modifier(KeyboardTopSpacingModifier(spacing: spacing, isActive: isActive))
    }
}
