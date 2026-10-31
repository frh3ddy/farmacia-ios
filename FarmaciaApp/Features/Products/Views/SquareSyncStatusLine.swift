import SwiftUI
import FarmaciaKit

// MARK: - Square Sync Status Line

/// "No sincronizado con Square" under a receiving or adjustment whose push to
/// Square failed. Reintentar shows only when the screen passes a retry (owners).
struct SquareSyncStatusLine: View {
    let synced: Bool?
    let error: String?
    var onRetry: (() async -> Void)?

    @State private var isRetrying = false

    var body: some View {
        if SquareSync.failed(synced: synced, error: error) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("No sincronizado con Square")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Spacer()

                if let onRetry {
                    Button {
                        guard !isRetrying else { return }
                        isRetrying = true
                        Task {
                            await onRetry()
                            isRetrying = false
                        }
                    } label: {
                        if isRetrying {
                            ProgressView()
                        } else {
                            Text("Reintentar")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderless)
                    .disabled(isRetrying)
                }
            }
            .padding(.top, 2)
        }
    }
}
