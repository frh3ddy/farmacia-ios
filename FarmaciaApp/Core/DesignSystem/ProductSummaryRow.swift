import SwiftUI

// MARK: - Product Summary Row
//
// The top row of a form that acts on one product (Recibir Inventario, Ajuste):
// what's being changed — photo, name, and "SKU · stock · price".

struct ProductSummaryRow: View {
    let product: Product
    /// This store's stock as the form knows it (fresh when loaded, else the
    /// cached product's); nil hides it, e.g. where a count correction shows its own.
    let stock: Int?

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            CachedProductImage(url: product.squareImageUrl, targetSize: CGSize(width: 48, height: 48)) {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 48)
            .background(.fill.tertiary, in: .rect(cornerRadius: DS.Radius.m))
            .clipShape(.rect(cornerRadius: DS.Radius.m))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(product.displayName)
                    .font(.headline)
                Text(facts)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "SKU 123 · 12 en existencia · $25.00"
    private var facts: String {
        var facts: [String] = []
        if let sku = product.sku, !sku.isEmpty { facts.append("SKU \(sku)") }
        if let stock { facts.append("\(stock) en existencia") }
        if let price = product.sellingPrice { facts.append("$\(String(format: "%.2f", price))") }
        return facts.joined(separator: " · ")
    }
}
