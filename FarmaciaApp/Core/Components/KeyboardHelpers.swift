import SwiftUI
import FarmaciaKit

// MARK: - Form Keyboard
//
// One modifier for how every form's keyboard behaves. The rule: we never change
// the form's layout ourselves — only the system does (keyboard avoidance), so
// showing, hiding and drag-dismissing the keyboard stay one native motion.
//
//   - A bar above the keyboard: ‹ › walk the fields in `order`, Listo closes the
//     keyboard. The number pad has no return key, so without this the only way
//     out was tapping elsewhere. It's an overlay — it sits above the keyboard and
//     rises and falls with it, but never takes layout space. Both alternatives
//     made the form jump at the end of every dismiss (measured on device):
//       · the system keyboard toolbar (`placement: .keyboard`) adds 14pt to the
//         form's bottom inset and releases it only after the keyboard animation;
//       · a bar in `safeAreaInset` shrinks on its own clock.
//   - The focused field goes to a reading position (a third down), starting on
//     the keyboard's will-show with its duration and curve, so field and keyboard
//     rise together and the field stays clear of the bar. (Form alone scrolls the
//     field just above the keys, under the bar, and only after the keyboard
//     settles.) Needs each field's row to carry `.id(field)` (AmountField does;
//     plain TextFields use `.formField(_:focus:)`).
//   - The return key moves to the next field; on the last one it closes.
//   - Interactive dismissal, like Messages/Notes: the form scrolls freely with
//     the keyboard up, and dragging down into the keyboard closes it.
//     (`.immediately` closed it on any scroll, so trying to see more of the
//     form fought the keyboard's own shrink.)
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

    /// A text field in a `.formKeyboard` form: focusable as `field`, and
    /// findable for the form's scroll-into-place.
    func formField<Field: Hashable>(_ field: Field, focus: FocusState<Field?>.Binding) -> some View {
        focused(focus, equals: field).id(field)
    }
}

/// The keyboard's own animation, read from its show/hide notification: the
/// system's duration with the usual bezier match for UIKit's private keyboard
/// curve (7).
extension Animation {
    static func keyboard(_ note: Notification? = nil) -> Animation {
        let duration = (note?.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double)
            .flatMap { $0 > 0 ? $0 : nil } ?? 0.25
        return .timingCurve(0.38, 0.7, 0.125, 1.0, duration: duration)
    }
}

private struct FormKeyboardModifier<Field: Hashable>: ViewModifier {
    var focus: FocusState<Field?>.Binding
    let order: FocusOrder<Field>

    /// Between the keyboard's will-show and will-hide.
    @State private var keyboardUp = false

    private var previous: Field? { focus.wrappedValue.flatMap(order.previous(before:)) }
    private var next: Field? { focus.wrappedValue.flatMap(order.next(after:)) }

    /// Where a focused field settles: a third down, clear of keyboard and bar.
    private static var readingPosition: UnitPoint { UnitPoint(x: 0.5, y: 0.33) }

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .submitLabel(.next)
                .onSubmit { focus.wrappedValue = next }
                // Keyboard rising (or changing type between fields): bar and
                // scroll on its exact start and timing.
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                    withAnimation(.keyboard(note)) {
                        keyboardUp = true
                        if let field = focus.wrappedValue {
                            proxy.scrollTo(field, anchor: Self.readingPosition)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
                    withAnimation(.keyboard(note)) { keyboardUp = false }
                }
                // Moving between fields with the keyboard already up: no
                // notification comes, so scroll right away.
                .onChange(of: focus.wrappedValue) { _, field in
                    guard keyboardUp, let field else { return }
                    withAnimation(.keyboard()) {
                        proxy.scrollTo(field, anchor: Self.readingPosition)
                    }
                }
                .overlay(alignment: .bottom) {
                    if keyboardUp && focus.wrappedValue != nil {
                        keyboardBar
                    }
                }
                .scrollDismissesKeyboard(.interactively)
        }
    }

    private var keyboardBar: some View {
        HStack(spacing: DS.Spacing.xl) {
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
        .labelStyle(.iconOnly)
        .padding(.horizontal, DS.Spacing.l)
        .frame(minHeight: DS.minTapSize)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
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
