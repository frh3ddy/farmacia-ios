import SwiftUI

// MARK: - Offline Sync Issues
//
// Reviews writes the offline queue could not reconcile automatically (the
// server rejected the replay outright, or retries were exhausted) so nothing
// vanishes silently — the user decides to discard or handle it manually.

struct OfflineSyncIssuesView: View {
    let items: [QueuedRequest]
    var onDismiss: (QueuedRequest) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    AppEmptyStateView(
                        title: "Todo sincronizado",
                        systemImage: "checkmark.circle",
                        message: "No hay cambios pendientes por revisar."
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.summary)
                                .font(.subheadline.weight(.medium))
                            if let lastError = item.lastError {
                                Text(lastError)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Text(item.queuedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .swipeActions {
                            Button("Descartar", role: .destructive) {
                                onDismiss(item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cambios sin sincronizar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
