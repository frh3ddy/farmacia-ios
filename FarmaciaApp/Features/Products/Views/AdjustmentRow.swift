import SwiftUI
import FarmaciaKit

// MARK: - Adjustment Row

struct AdjustmentRow: View {
    let adjustment: InventoryAdjustment
    var onRetrySync: (() async -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
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
                ToneBadge(adjustment.type.displayName, color: typeColor)

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

            SquareSyncStatusLine(
                synced: adjustment.squareSynced,
                error: adjustment.squareSyncError,
                onRetry: onRetrySync
            )
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var typeColor: Color {
        StockChange(quantity: adjustment.quantity).tone.color
    }
}
