import SwiftUI
import FarmaciaKit

// MARK: - Adjustment Row

struct AdjustmentRow: View {
    let adjustment: InventoryAdjustment
    var onRetrySync: (() async -> Void)? = nil

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

            SquareSyncStatusLine(
                synced: adjustment.squareSynced,
                error: adjustment.squareSyncError,
                onRetry: onRetrySync
            )
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        StockChange(quantity: adjustment.quantity).color
    }
}

extension StockChange {
    /// Green for stock added, red for removed, orange for no change.
    var color: Color {
        switch self {
        case .added: .green
        case .removed: .red
        case .none: .orange
        }
    }
}
