import SwiftUI
import FarmaciaKit

// MARK: - Product Economics Box
// Price, cost and margin, then where the cost comes from (opens costs and suppliers).
// Values in, a closure out: no view models (ProductDetailView owns the loads and the sheet).

struct ProductEconomicsBox: View {
    let product: Product
    let canViewCosts: Bool
    /// Suppliers still loading: a placeholder instead of the average cost flipping to theirs.
    let isCostLoading: Bool
    /// The one cost this screen shows, and its margin uses (`UnitCost.pick`).
    let unitCost: UnitCost?
    let supplierCount: Int
    let onShowSuppliers: () -> Void

    var body: some View {
        economicsBox

        if canViewCosts, !isCostLoading, let unitCost {
            provenanceRow(unitCost)
        }
    }

    private var economicsBox: some View {
        // Cost: never for a cashier, even if a cached row still carries one.
        let cost = canViewCosts && !isCostLoading ? unitCost?.cost : nil
        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Precio de venta")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let price = product.sellingPrice {
                        MoneyText(amount: price)
                    } else {
                        Text("No definido")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if canViewCosts {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text("Costo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if isCostLoading {
                            MoneyText(amount: 0)
                                .redacted(reason: .placeholder)
                                .accessibilityLabel("Cargando costo")
                        } else if let cost {
                            MoneyText(amount: cost)
                        } else {
                            Text("—")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let price = product.sellingPrice, let cost, let margin = PriceMargin(price: price, cost: cost) {
                Divider()
                marginLine(margin)
            }
        }
        .padding(DS.Spacing.m)
        .background(Color(.systemBackground), in: .rect(cornerRadius: DS.Radius.l))
    }

    /// "Margen 55.5% · $122.00 por unidad", currency stated once. One Text, so it wraps.
    private func marginLine(_ margin: PriceMargin) -> some View {
        let glyph = margin.tone == .positive
            ? Text("")
            : Text("\(Image(systemName: "exclamationmark.triangle.fill")) ").foregroundStyle(margin.tone.color)
        let percent = Text(String(format: "%.1f%%", margin.percent))
            .fontWeight(.semibold)
            .foregroundStyle(margin.tone.color)
        let perUnit = Text(ReportFormat.currency(margin.perUnit))
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
        return HStack(alignment: .firstTextBaseline) {
            Text("Margen \(glyph)\(percent) · \(perUnit) por unidad")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            Text(product.currency ?? "MXN")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Where the cost comes from ("Simi · Mejor precio · compra 1 nov"); opens costs and suppliers.
    /// The cost itself is printed once, above.
    private func provenanceRow(_ unitCost: UnitCost) -> some View {
        Button {
            onShowSuppliers()
        } label: {
            HStack(spacing: DS.Spacing.s) {
                switch unitCost.source {
                case .supplier(let name, let lastPurchase):
                    Image(systemName: "building.2")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(name)
                                .fontWeight(.medium)
                            if unitCost.isBestPrice {
                                ToneBadge("Mejor precio", tone: .positive)
                            }
                        }
                        let detail = [
                            lastPurchase.map { "compra \(DisplayDate.shortDay($0))" },
                            unitCost.showsAllSuppliers ? "\(supplierCount) proveedores" : nil,
                        ].compactMap { $0 }
                        if !detail.isEmpty {
                            Text(detail.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                case .average:
                    Image(systemName: "function")
                        .foregroundStyle(.secondary)
                    Text("Costo promedio del inventario")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .font(.subheadline)
            .frame(minHeight: DS.minTapSize)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ver costos y proveedores")
    }
}
