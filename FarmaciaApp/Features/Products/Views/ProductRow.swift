import SwiftUI

// MARK: - Product Row (Enhanced with stock badges and margin)

struct ProductRow: View {
    let product: Product
    var riskLevel: InventoryRiskLevel? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image or Placeholder (cached + downsampled to display size)
            if product.squareImageUrl != nil {
                CachedProductImage(url: product.squareImageUrl, targetSize: CGSize(width: 50, height: 50)) {
                    productPlaceholder
                }
                .frame(width: 50, height: 50)
                .clipShape(.rect(cornerRadius: 8))
            } else {
                productPlaceholder
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
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
                            .foregroundStyle(.green)
                    }
                    
                    // Stock badge
                    stockBadge
                    
                    // Risk badge (from aging service)
                    if let risk = riskLevel, risk == .high || risk == .critical {
                        Text(risk == .critical ? "CRIT" : "RISK")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(risk.color.opacity(0.15))
                            .foregroundStyle(risk.color)
                            .clipShape(.rect(cornerRadius: 3))
                    }
                }
            }
            
            Spacer()
            
            // Price, Margin, and Stock
            VStack(alignment: .trailing, spacing: 4) {
                if let price = product.formattedPrice {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Margin indicator
                if let margin = product.profitMargin {
                    Text(String(format: "%.0f%%", margin))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(marginColor(margin).opacity(0.15))
                        .foregroundStyle(marginColor(margin))
                        .clipShape(.rect(cornerRadius: 4))
                }
                
                if let stock = product.totalInventory {
                    Text("\(stock) uds")
                        .font(.caption)
                        .foregroundStyle(stock > 0 ? Color.secondary : Color.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stockBadge: some View {
        Group {
            let stock = product.totalInventory ?? 0
            if stock == 0 {
                Text("OUT")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(.rect(cornerRadius: 3))
            } else if stock < 10 {
                Text("LOW")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(.rect(cornerRadius: 3))
            }
        }
    }
    
    private func marginColor(_ margin: Double) -> Color {
        if margin >= 20 { return .green }
        if margin >= 10 { return .orange }
        return .red
    }
    
    private var productPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
            
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
    }
}

