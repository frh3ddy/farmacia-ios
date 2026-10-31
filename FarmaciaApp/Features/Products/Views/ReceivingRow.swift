import SwiftUI
import FarmaciaKit

// MARK: - Receiving Row

struct ReceivingRow: View {
    let receiving: InventoryReceiving
    var onRetrySync: (() async -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(receiving.product?.displayName ?? "Producto Desconocido")
                    .font(.headline)
                Spacer()
                Text("+\(receiving.quantity)")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            HStack {
                if let invoiceNumber = receiving.invoiceNumber {
                    Text("Factura: \(invoiceNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(ReportFormat.currency(receiving.unitCost))/unidad")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(receiving.receivedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total: \(ReportFormat.currency(receiving.totalCost))")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            SquareSyncStatusLine(
                synced: receiving.squareSynced,
                error: receiving.squareSyncError,
                onRetry: onRetrySync
            )
        }
        .padding(.vertical, 4)
    }
}
