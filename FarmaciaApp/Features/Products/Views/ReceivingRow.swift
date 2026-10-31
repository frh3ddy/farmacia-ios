import SwiftUI

// MARK: - Receiving Row

struct ReceivingRow: View {
    let receiving: InventoryReceiving

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
                Text("$\(receiving.unitCost)/unit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(receiving.receivedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total: $\(receiving.totalCost)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}
