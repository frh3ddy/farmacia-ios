import SwiftUI
import FarmaciaKit

// MARK: - Receiving Review Sheet
//
// Before a receiving that also changes the sale price is posted: what it does,
// in one place (docs/inventory-ux-brief.md §5D) — stock, cost, the price change
// and its margin. Choices about the consequence live here, next to the preview,
// not in the form (Square's pattern): the owner picks whether the new price
// applies at every store.

struct ReceivingReviewSheet: View {
    struct Summary {
        let productName: String
        let quantity: Int
        let unitCost: Double
        let supplierName: String?
        let storeName: String
        let stockImpact: StockImpact?
        let currentPrice: Double?
        let newPrice: Double
    }

    let summary: Summary
    /// Owner only (`PriceEditing.canApplyToAllLocations`).
    let canApplyToAllLocations: Bool
    @Binding var priceAtAllLocations: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var margin: Double? {
        Margin.percent(price: summary.newPrice, cost: summary.unitCost)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Producto", value: summary.productName)
                    LabeledContent("Cantidad", value: "\(summary.quantity) uds")
                    LabeledContent("Costo") {
                        Text("\(summary.unitCost.mxn) c/u · \((Double(summary.quantity) * summary.unitCost).mxn)")
                            .monospacedDigit()
                    }
                    LabeledContent("Proveedor", value: summary.supplierName ?? "Sin proveedor")
                    if let impact = summary.stockImpact {
                        LabeledContent(summary.storeName) {
                            Text(impact.summary).monospacedDigit()
                        }
                    }
                } header: {
                    Text("Inventario")
                }

                Section {
                    LabeledContent("Precio") {
                        HStack(spacing: DS.Spacing.s) {
                            if let current = summary.currentPrice {
                                Text(current.mxn)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("a")
                            }
                            Text(summary.newPrice.mxn).bold()
                        }
                        .monospacedDigit()
                    }
                    if let margin {
                        LabeledContent("Margen") {
                            Text("\(Int(margin.rounded()))%")
                                .foregroundStyle(Margin.tone(forPercent: margin).color)
                        }
                    }
                    if canApplyToAllLocations {
                        Toggle("Aplicar en todas las sucursales", isOn: $priceAtAllLocations)
                    }
                } header: {
                    Text("Precio de venta")
                } footer: {
                    Text(priceAtAllLocations
                        ? "El nuevo precio se aplica en todas las sucursales y en Square POS."
                        : "Solo cambia en \(summary.storeName) y en su Square POS; las demás sucursales conservan su precio.")
                }
            }
            .navigationTitle("Revisar recepción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Volver") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: confirm) {
                    Text("Confirmar recepción")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: DS.minTapSize)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: DS.Radius.l))
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.s)
                .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func confirm() {
        dismiss()
        onConfirm()
    }
}
