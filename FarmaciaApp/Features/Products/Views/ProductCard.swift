import SwiftUI
import FarmaciaKit

// MARK: - Product Card
//
// Productos' card layout: photo, codes and badges, the full name, then a row of
// labelled figures (UX brief §5C: labels, right-aligned numbers, units). Cost,
// stock value and margin only when the role can view costs (`ProductFigures`).

struct ProductCard: View {
    let product: Product
    var riskLevel: InventoryRiskLevel? = nil
    /// Pass `authManager.canViewCosts`. Off unless asked, like `ProductRow.showsMargin`.
    var canViewCosts = false

    private static let imageSize: CGFloat = 64

    private var figures: ProductFigures {
        ProductFigures(price: product.sellingPrice, cost: product.averageCost, stock: product.totalInventory,
                       tracksInventory: product.tracksInventory, canViewCosts: canViewCosts)
    }

    var body: some View {
        let figures = figures
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                image
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    codes
                    badges(figures)
                    Text(product.fullName)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Divider()
            ProductCardFigures(figures: figureList(figures))
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: Header

    @ViewBuilder
    private var image: some View {
        let size = CGSize(width: Self.imageSize, height: Self.imageSize)
        Group {
            if product.squareImageUrl != nil {
                CachedProductImage(url: product.squareImageUrl, targetSize: size) { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: DS.Radius.m))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.fill.tertiary)
            Image(systemName: "shippingbox").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var codes: some View {
        let lines = ProductCodes.lines(sku: product.sku, gtin: product.gtin)
        if !lines.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.s) { codeTexts(lines) }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) { codeTexts(lines) }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func codeTexts(_ lines: [ProductCodes.Line]) -> some View {
        ForEach(lines, id: \.text) { line in
            switch line {
            case .sku(let code): Text(code).accessibilityLabel("SKU \(code)")
            case .barcode(let code):
                Label(code, systemImage: "barcode")
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("Código de barras \(code)")
            }
        }
    }

    @ViewBuilder
    private func badges(_ figures: ProductFigures) -> some View {
        let level = figures.stock.map { StockLevel(quantity: $0, alert: product.stockAlert) }
        let label = figures.stock.flatMap { StockLevel.badgeText(quantity: $0, alert: product.stockAlert) }
        let risky = riskLevel == .high || riskLevel == .critical
        if label != nil || risky || figures.marginPercent != nil || product.hasSquareSync == true {
            HStack(spacing: DS.Spacing.xs) {
                if let level, let label { ToneBadge(label, tone: level.tone) }
                if risky, let riskLevel {
                    ToneBadge(riskLevel == .critical ? "Crítico" : "Riesgo", color: riskLevel.color)
                }
                if let margin = figures.marginPercent {
                    ToneBadge(String(format: "%.0f%%", margin), tone: Margin.tone(forPercent: margin))
                        .accessibilityLabel(String(format: "Margen %.0f%%", margin))
                }
                if product.hasSquareSync == true {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Tone.positive.color)
                        .accessibilityLabel("Sincronizado con Square")
                }
            }
        }
    }

    // MARK: Figures

    private func figureList(_ f: ProductFigures) -> [ProductCardFigures.Figure] {
        var list: [ProductCardFigures.Figure] = []
        list.append(.init(label: "Precio", value: f.price.map(money) ?? "—"))
        if canViewCosts { list.append(.init(label: "Costo prom.", value: f.cost.map(money) ?? "—")) }
        if let stock = f.stock {
            let level = StockLevel(quantity: stock, alert: product.stockAlert)
            list.append(.init(label: "Stock", value: "\(stock)", unit: "uds",
                               color: level == .ok ? .primary : level.tone.color))
        }
        if canViewCosts, f.stock != nil { list.append(.init(label: "Valor", value: f.stockValue.map(money) ?? "—")) }
        return list
    }

    private func money(_ amount: Double) -> String {
        Product.currencyFormatter(for: product.currency ?? "MXN").string(from: NSNumber(value: amount)) ?? "—"
    }
}

private extension ProductCodes.Line {
    var text: String {
        switch self {
        case .sku(let s), .barcode(let s): s
        }
    }
}

// MARK: - Figures row

/// Labelled, right-aligned figures in one row; a 2-column grid when they don't fit
/// (accessibility text sizes).
private struct ProductCardFigures: View {
    struct Figure {
        let label: String
        let value: String
        var unit: String? = nil
        var color: Color = .primary
    }

    let figures: [Figure]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: DS.Spacing.s) {
                ForEach(figures, id: \.label) { figure in
                    FigureView(figure: figure).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            Grid(alignment: .trailing, horizontalSpacing: DS.Spacing.l, verticalSpacing: DS.Spacing.s) {
                ForEach(Array(stride(from: 0, to: figures.count, by: 2)), id: \.self) { i in
                    GridRow {
                        FigureView(figure: figures[i])
                        if i + 1 < figures.count { FigureView(figure: figures[i + 1]) }
                    }
                }
            }
        }
    }

    private struct FigureView: View {
        let figure: Figure

        var body: some View {
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(figure.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                    Text(figure.value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(figure.color)
                    if let unit = figure.unit {
                        Text(unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
            }
        }
    }
}
