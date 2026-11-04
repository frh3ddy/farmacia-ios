import SwiftUI
import FarmaciaKit

// MARK: - Field Error

extension View {
    /// After a failed submit: `message` under the field and a red tint on its
    /// row. Each change of `shake` shakes the rows that have an error.
    ///
    /// Put it on the row's top-level view: it also gives the row the id
    /// `field`, which `.formKeyboard` scrolls to. Inside a Form, `scrollTo`
    /// only finds a row-level id — one nested in a stack is silently ignored
    /// and the field stays under the keyboard bar.
    func fieldError<Field: Hashable>(_ message: String?, shake: Int, field: Field) -> some View {
        modifier(FieldErrorModifier(message: message, shake: shake)).id(field)
    }
}

private struct FieldErrorModifier: ViewModifier {
    let message: String?
    let shake: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            content
            if let message {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Tone.critical.color)
                    .transition(.opacity)
            }
        }
        .modifier(Shake(travel: message == nil || reduceMotion ? 0 : 6, phase: CGFloat(shake)))
        .animation(.linear(duration: 0.4), value: shake)
        .animation(.default, value: message)
        .listRowBackground(message == nil ? nil : Tone.critical.color.opacity(0.08))
    }
}

/// Three quick side-to-side moves as `phase` goes up by one.
private struct Shake: GeometryEffect {
    var travel: CGFloat
    var phase: CGFloat
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(phase * .pi * 6), y: 0))
    }
}
