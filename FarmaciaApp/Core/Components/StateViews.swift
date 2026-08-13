import SwiftUI

// MARK: - Loading State
//
// A single centered spinner + message, standing in for the many ad hoc
// `VStack { ProgressView(); Text(...) }` blocks scattered across feature
// screens with slightly different spacing/styling each time.

struct LoadingStateView: View {
    var message: String = "Cargando..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty / Unavailable State
//
// Thin wrapper around the native `ContentUnavailableView` (iOS 17+) so every
// screen gets the same title/icon/description/retry layout instead of
// hand-rolling its own VStack. Pass `retryAction` only when the empty state
// can be a load failure as well as a genuine empty result — screens that
// need to tell those two apart should pass a different `message` too.

struct AppEmptyStateView: View {
    let title: String
    let systemImage: String
    var message: String? = nil
    var retryAction: (() -> Void)? = nil

    var body: some View {
        if let retryAction {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                if let message {
                    Text(message)
                }
            } actions: {
                Button("Reintentar", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: message.map { Text($0) }
            )
        }
    }
}

// MARK: - Error Alert
//
// Binds a standard "Error" / "OK" alert to a view model's `showError`/
// `errorMessage` pair. Centralizes boilerplate that was previously
// duplicated per screen — and, more importantly, sometimes silently
// missing on a view presented as a sheet on top of the screen that
// actually owns the alert (SwiftUI won't surface an alert whose modifier
// lives on an obscured presenter). Attach this on every presentation layer
// that can produce the error, not just the outermost one.

struct ErrorAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String?

    func body(content: Content) -> some View {
        content.alert("Error", isPresented: $isPresented) {
            Button("OK") {}
        } message: {
            Text(message ?? "Ocurrió un error")
        }
    }
}

extension View {
    func errorAlert(isPresented: Binding<Bool>, message: String?) -> some View {
        modifier(ErrorAlertModifier(isPresented: isPresented, message: message))
    }
}
