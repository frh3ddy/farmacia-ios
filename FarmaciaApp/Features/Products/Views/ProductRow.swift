import SwiftUI
import FarmaciaKit

// MARK: - Product Row (Enhanced with stock badges and margin)

struct ProductRow: View {
    let product: Product
    var riskLevel: InventoryRiskLevel? = nil
    /// Margin comes from cost: pass `authManager.canViewCosts`. Off unless asked, so a
    /// list that forgets can't show a cashier margins (e.g. from a cached owner row).
    var showsMargin = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            // Product Image or Placeholder (cached + downsampled to display size)
            if product.squareImageUrl != nil {
                CachedProductImage(url: product.squareImageUrl, targetSize: CGSize(width: 50, height: 50)) {
                    productPlaceholder
                }
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: DS.Radius.m))
            } else {
                productPlaceholder
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(product.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let sku = product.sku {
                        Text(sku)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if product.hasSquareSync == true {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Tone.positive.color)
                    }
                    
                    // Stock badge
                    stockBadge
                    
                    // Risk badge (from aging service)
                    if let risk = riskLevel, risk == .high || risk == .critical {
                        ToneBadge(risk == .critical ? "Crítico" : "Riesgo", color: risk.color)
                    }
                }
            }
            
            Spacer()
            
            // Price, Margin, and Stock
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                if let price = product.formattedPrice {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Margin indicator
                if showsMargin, let margin = product.profitMargin {
                    ToneBadge(String(format: "%.0f%%", margin), tone: Margin.tone(forPercent: margin))
                }
                
                if let stock = product.totalInventory {
                    Text("\(stock) uds")
                        .font(.caption)
                        .foregroundStyle(StockLevel(quantity: stock) == .out ? Tone.critical.color : .secondary)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
    
    /// Shown with no stock info too (counts as 0), as before.
    @ViewBuilder
    private var stockBadge: some View {
        let level = StockLevel(quantity: product.totalInventory ?? 0)
        if let label = level.label {
            ToneBadge(label, tone: level.tone)
        }
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .fill(.fill.tertiary)
                .frame(width: 50, height: 50)
            
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
    }
}

