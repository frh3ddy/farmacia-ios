import SwiftUI
import UIKit

// MARK: - Tap-Outside-to-Dismiss (WhatsApp-style)
//
// A single window-level tap recognizer resigns the first responder when the
// user taps anywhere outside an editable text input. The recognizer does NOT
// consume touches (`cancelsTouchesInView = false`), so buttons, pickers and
// list rows keep working normally — only the keyboard goes away.
// Taps that land inside another UITextField/UITextView are ignored so focus
// can move between fields without the keyboard flickering.

@MainActor
enum KeyboardDismissInstaller {
    private static var isInstalled = false

    /// Attaches the dismiss recognizer to every window of the active scene.
    /// Idempotent — safe to call from `onAppear`.
    static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else { return }

        for window in scene.windows {
            let tap = UITapGestureRecognizer(
                target: KeyboardDismissHandler.shared,
                action: #selector(KeyboardDismissHandler.handleTap(_:))
            )
            tap.cancelsTouchesInView = false
            tap.delegate = KeyboardDismissHandler.shared
            window.addGestureRecognizer(tap)
        }
    }
}

@MainActor
final class KeyboardDismissHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissHandler()

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        gesture.view?.endEditing(true)
    }

    /// Ignore taps that land inside an editable text input (or its accessory
    /// views) so moving focus between fields doesn't dismiss the keyboard.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView {
                return false
            }
            view = current.superview
        }
        return true
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
