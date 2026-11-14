import SwiftUI
import FarmaciaKit

// MARK: - Product Lots Section (FIFO)
// Owners and managers: the lots in the order FIFO sells them, their age and expiry.

struct ProductLotsSection: View {
    let batches: [BatchValuation]
    let isLoading: Bool
    let productAging: ProductAgingAnalysis?
    let cashAtRisk: Double
    let stockHere: Int
    let onSelectBatch: (String) -> Void

    @State private var showAllBatches = false

    var body: some View {
        fifoBatchSection
    }

    private var fifoBatchSection: some View {
        let batches = batches
        return VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Label("Lotes (FIFO)", systemImage: "square.stack.3d.up")
                    .font(.headline)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if !batches.isEmpty {
                    Text("\(batches.count) lote\(batches.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if batches.isEmpty && !isLoading {
                Text("Sin lotes de inventario")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !batches.isEmpty {
                // One chip, neutral unless something needs attention; shelf age in words.
                let alert = ProductAlert.worst(
                    lots: LotSummary(lots: batches),
                    stockHere: stockHere,
                    risk: productAging?.riskLevel
                )
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
                    ToneBadge(alert.label, tone: alert.tone, systemImage: alert.systemImage)
                    if let sentence = AgingSentence.text(lots: batches) {
                        Text(sentence)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let aging = productAging, !aging.bucketDistribution.isEmpty {
                    agingBar(aging)
                }

                // Cash at risk callout (if any >90d inventory)
                let atRiskCash = cashAtRisk
                if atRiskCash > 0 {
                    StatusLabel("\(ReportFormat.currency(atRiskCash)) con más de 90 días", tone: .critical)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                // Lots in the order FIFO sells them (first 3 = next to sell, expand for all)
                let sortedBatches = BatchValuation.fifoOrder(batches)
                let nextOutId = BatchValuation.nextOut(batches)?.id
                if case .list(let shown, let hasMore) = ListPreview(count: sortedBatches.count, limit: 3) {
                    let batchesToShow = showAllBatches ? sortedBatches : Array(sortedBatches.prefix(shown))
                    ForEach(batchesToShow) { batch in
                        Divider()
                        Button {
                            onSelectBatch(batch.batchId)
                        } label: {
                            batchRow(batch, isNextOut: batch.id == nextOutId)
                        }
                        .buttonStyle(.plain)
                    }

                    if hasMore {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllBatches.toggle()
                            }
                        } label: {
                            HStack {
                                Text(showAllBatches ? "Ver menos" : "Ver todos")
                                Image(systemName: showAllBatches ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .frame(minHeight: DS.minTapSize)
                            .contentShape(.rect)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// The aging service's buckets as a bar, with text labels so it isn't color alone.
    private func agingBar(_ aging: ProductAgingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            SegmentedBar(fractions: aging.bucketDistribution.map { $0.percentageOfTotal / 100 },
                         spacing: 1, minimum: 2) {
                ForEach(aging.bucketDistribution) { bucket in
                    Rectangle()
                        .fill(BatchAge.tone(days: bucket.bucket.min).color)
                }
            }
            .frame(height: 6)
            .clipShape(.rect(cornerRadius: 3))
            .accessibilityHidden(true)

            HStack(spacing: DS.Spacing.s) {
                ForEach(aging.bucketDistribution) { bucket in
                    HStack(spacing: 3) {
                        Text("\(bucket.unitCount)")
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text(bucket.bucket.label)
                    }
                }
                Spacer()
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
    }

    /// "2 uds × $98.00 · Sale siguiente … $196.00 valor del lote", received line, metadata, expiry row.
    private func batchRow(_ batch: BatchValuation, isNextOut: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text("\(batch.quantity) uds × \(ReportFormat.currency(batch.unitCost))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                if isNextOut {
                    ToneBadge("Sale siguiente", tone: .info)
                }
                Spacer(minLength: DS.Spacing.s)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(ReportFormat.currency(batch.value))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text("valor del lote")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(receivedLine(batch))
                .font(.caption)
                .foregroundStyle(.secondary)

            let pills = batchMetadataPills(batch)
            if !pills.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(pills, id: \.label) { pill in
                            ToneBadge(pill.label, color: pill.color, systemImage: pill.icon)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            expiryRow(batch)
        }
        .padding(.vertical, DS.Spacing.xxs)
        .contentShape(.rect)
    }

    /// "Recibido 1 nov · saldo inicial · hace 2 días".
    private func receivedLine(_ batch: BatchValuation) -> String {
        var parts = ["Recibido \(DisplayDate.shortDay(batch.receivedAt))"]
        if batch.source != nil {
            parts.append(batch.sourceLabel.lowercased())
        }
        parts.append(batch.age == 1 ? "hace 1 día" : "hace \(batch.age) días")
        return parts.joined(separator: " · ")
    }

    /// The caducidad is the field that matters most for a medicine: always a row, tinted by `Expiry.tone`.
    @ViewBuilder
    private func expiryRow(_ batch: BatchValuation) -> some View {
        if let expiry = batch.expiryDate {
            let days = Expiry.daysUntil(expiry)
            let tone = Expiry.tone(daysUntil: days)
            let text = days < 0
                ? "\(Expiry.display(expiry)) · \(Expiry.countdown(daysUntil: days))"
                : "Vence \(Expiry.display(expiry)) · \(Expiry.countdown(daysUntil: days))"
            Label(text, systemImage: tone.systemImage)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(tone == .neutral ? .primary : tone.color)
                .padding(.horizontal, DS.Spacing.s)
                .padding(.vertical, DS.Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((tone == .neutral ? Color(.systemGray5) : tone.color.opacity(0.12)), in: .rect(cornerRadius: DS.Radius.m))
        } else {
            Label("Sin caducidad registrada", systemImage: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private struct BatchPill: Hashable {
        let icon: String
        let label: String
        let color: Color
    }

    /// Lot number, supplier, invoice. The expiry has its own row.
    private func batchMetadataPills(_ batch: BatchValuation) -> [BatchPill] {
        var pills: [BatchPill] = []

        if let lot = batch.batchNumber, !lot.isEmpty {
            pills.append(BatchPill(icon: "number", label: lot, color: .purple))
        }

        if let supplier = batch.supplierName, !supplier.isEmpty {
            pills.append(BatchPill(icon: "building.2", label: supplier, color: .blue))
        }

        if let invoice = batch.invoiceNumber, !invoice.isEmpty {
            pills.append(BatchPill(icon: "doc.text", label: invoice, color: .gray))
        }

        return pills
    }
}

/// The aging bar's segments, sized by `BarSegments`: every bucket with units visible,
/// the whole bar exactly the available width.
private struct SegmentedBar: Layout {
    let fractions: [Double]
    let spacing: CGFloat
    let minimum: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = BarSegments.widths(fractions: fractions, total: bounds.width, spacing: spacing, minimum: minimum)
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            // Empty buckets are placed at zero width: an unplaced subview would be centered.
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: bounds.height))
            if width > 0 { x += width + spacing }
        }
    }
}
