import SwiftUI
import FarmaciaKit

// MARK: - Adjustment Row

struct AdjustmentRow: View {
    let adjustment: InventoryAdjustment
    var onRetrySync: (() async -> Void)? = nil

    @State private var isRetrying = false

    private var syncFailed: Bool {
        adjustment.squareSyncError != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: adjustment.type.icon)
                    .foregroundStyle(typeColor)

                Text(adjustment.product?.displayName ?? "Producto Desconocido")
                    .font(.headline)

                Spacer()

                Text(adjustment.quantityDisplay)
                    .font(.headline)
                    .foregroundStyle(typeColor)
            }

            HStack {
                Text(adjustment.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(.rect(cornerRadius: 4))

                if let reason = adjustment.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(adjustment.adjustedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if syncFailed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("No sincronizado con Square")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Spacer()

                    Button {
                        guard let onRetrySync, !isRetrying else { return }
                        isRetrying = true
                        Task {
                            await onRetrySync()
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
                    .disabled(isRetrying || onRetrySync == nil)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        switch StockChange(quantity: adjustment.quantity) {
        case .added: .green
        case .removed: .red
        case .none: .orange
        }
    }
}
