import SwiftUI
import FarmaciaKit

// MARK: - Offline Sync Banner
//
// Thin status bar pinned under the navigation bar (via .safeAreaInset) so it
// never covers content. Shows at most one thing at a time, in priority order:
// sync problems that need a decision > offline > actively syncing > another
// employee's writes waiting for them to log in (they sync only under their session).

struct OfflineSyncBanner: View {
    let isOffline: Bool
    let pendingCount: Int
    let failedCount: Int
    var othersWaiting: [String] = []
    var onTapFailed: () -> Void

    var body: some View {
        if failedCount > 0 {
            Button(action: onTapFailed) {
                row(
                    systemImage: "exclamationmark.triangle.fill",
                    text: failedText,
                    tint: .red
                )
            }
            .buttonStyle(.plain)
        } else if isOffline {
            row(systemImage: "wifi.slash", text: offlineText, tint: .orange)
        } else if pendingCount > 0 {
            row(systemImage: "arrow.triangle.2.circlepath", text: syncingText, tint: .blue)
        } else if !othersWaiting.isEmpty {
            row(systemImage: "person.crop.circle.badge.clock", text: OfflineReplay.othersWaitingText(othersWaiting), tint: .gray)
        }
    }

    private var offlineText: String {
        pendingCount > 0
            ? "Sin conexión — \(pendingCount) cambio\(pendingCount == 1 ? "" : "s") pendiente\(pendingCount == 1 ? "" : "s")"
            : "Sin conexión"
    }

    private var syncingText: String {
        "Sincronizando \(pendingCount) cambio\(pendingCount == 1 ? "" : "s")…"
    }

    private var failedText: String {
        "\(failedCount) cambio\(failedCount == 1 ? "" : "s") no se pudo sincronizar. Toca para revisar."
    }

    private func row(systemImage: String, text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(tint)
        .accessibilityElement(children: .combine)
    }
}
