import SwiftUI
import FarmaciaKit

// MARK: - Offline Sync Banner
//
// The sync status. On iOS 26.1+ it's the tab bar accessory (the slot above the
// tab bar — `.accessory` style, on the system's glass); before that, a thin
// colored bar in the top safe area (`.bar`). A root-level top inset on iOS 26
// sat over the tab screens' navigation bar buttons. Shows at most one thing at a time, in priority order:
// sync problems that need a decision > offline > actively syncing > another
// employee's writes waiting for them to log in (they sync only under their session).

struct OfflineSyncBanner: View {
    let isOffline: Bool
    let pendingCount: Int
    let failedCount: Int
    var othersWaiting: [String] = []
    var style: Style = .bar
    var onTapFailed: () -> Void

    enum Style {
        /// Colored strip, white text (top safe area, before iOS 26.1).
        case bar
        /// Tinted icon, primary text, on the tab bar accessory's glass.
        case accessory
    }

    var body: some View {
        if failedCount > 0 {
            Button(action: onTapFailed) {
                row(
                    systemImage: "exclamationmark.triangle.fill",
                    text: failedText,
                    tint: Tone.critical.color
                )
            }
            .buttonStyle(.plain)
        } else if isOffline {
            row(systemImage: "wifi.slash", text: offlineText, tint: Tone.caution.color)
        } else if pendingCount > 0 {
            row(systemImage: "arrow.triangle.2.circlepath", text: syncingText, tint: Tone.info.color)
        } else if !othersWaiting.isEmpty {
            row(systemImage: "person.crop.circle.badge.clock", text: OfflineReplay.othersWaitingText(othersWaiting), tint: Tone.neutral.color)
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

    @ViewBuilder
    private func row(systemImage: String, text: String, tint: Color) -> some View {
        switch style {
        case .bar:
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: systemImage)
                Text(text)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(tint)
            .accessibilityElement(children: .combine)
        case .accessory:
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.l)
            .accessibilityElement(children: .combine)
        }
    }
}
