import SwiftUI
import FarmaciaKit

// MARK: - Batch Detail View
// Tapped from a lot row in ProductDetailView's Lotes FIFO section.
// Shows the lot's receipt (or the adjustment that created it), how much is left,
// and every sale/adjustment that took units from it.

struct BatchDetailView: View {
    let batchId: String
    let productName: String

    @StateObject private var viewModel = BatchDetailViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Cargando lote…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = viewModel.batchDetail {
                    ScrollView {
                        VStack(spacing: DS.Spacing.l) {
                            overviewCard(detail)
                            if let receiving = detail.receiving {
                                receivingCard(receiving)
                            }
                            if let adjustment = detail.adjustment {
                                adjustmentCard(adjustment)
                            }
                            quantityCard(detail)
                            historyCard(detail)
                        }
                        .padding()
                    }
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("No se pudo cargar el lote", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") {
                            Task { await viewModel.loadBatchDetail(batchId: batchId) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Lote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadBatchDetail(batchId: batchId)
        }
    }

    // MARK: - Overview

    private func overviewCard(_ detail: BatchDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                cardTitle("Resumen", systemImage: "square.stack.3d.up.fill", color: .teal)
                Spacer()
                ToneBadge(detail.sourceLabel, tone: .info)
            }

            Divider()

            HStack {
                Text(productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let sku = detail.productSku {
                    Text(sku)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: DS.Spacing.m) {
                metricBox(value: "\(detail.quantity)", label: "Restante",
                          tone: StockLevel(quantity: detail.quantity) == .out ? .critical : .neutral)
                metricBox(value: detail.formattedUnitCost, label: "Costo unitario", tone: .neutral)
                metricBox(value: "\(detail.ageDays) días", label: "Antigüedad", tone: BatchAge.tone(days: detail.ageDays))
            }

            HStack {
                Label(detail.locationName, systemImage: "building.2")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Valor: \(detail.formattedCurrentValue)")
                    .fontWeight(.semibold)
            }
            .font(.caption)
        }
        .card()
    }

    // MARK: - Receipt

    private func receivingCard(_ receiving: BatchReceivingDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            cardTitle("Recepción", systemImage: "arrow.down.doc.fill", color: .green)

            Divider()

            VStack(spacing: DS.Spacing.s) {
                if let supplier = receiving.supplierName {
                    infoRow(icon: "building.2", label: "Proveedor", value: supplier)
                }
                if let lot = receiving.batchNumber, !lot.isEmpty {
                    infoRow(icon: "number", label: "Lote", value: lot)
                }
                if let expiry = receiving.expiryDate {
                    let tone = Expiry.tone(daysUntil: Expiry.daysUntil(expiry))
                    infoRow(
                        icon: tone.systemImage,
                        label: tone == .critical ? "Vencido" : "Vence",
                        value: Expiry.display(expiry),
                        color: tone.color
                    )
                }
                if let mfg = receiving.manufacturingDate {
                    infoRow(icon: "hammer", label: "Fabricación", value: Expiry.display(mfg))
                }
                if let invoice = receiving.invoiceNumber, !invoice.isEmpty {
                    infoRow(icon: "doc.text", label: "Factura", value: invoice)
                }
                infoRow(icon: "clock", label: "Recibido", value: receiving.receivedAt.formatted(date: .abbreviated, time: .shortened))
                if let notes = receiving.notes, !notes.isEmpty {
                    infoRow(icon: "note.text", label: "Notas", value: notes)
                }
            }
        }
        .card()
    }

    // MARK: - Created by Adjustment

    private func adjustmentCard(_ adjustment: BatchAdjustmentDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            cardTitle("Creado por ajuste", systemImage: "arrow.triangle.2.circlepath", color: .orange)

            Divider()

            VStack(spacing: DS.Spacing.s) {
                infoRow(icon: "tag", label: "Tipo", value: AdjustmentType.label(adjustment.type))
                if let reason = adjustment.reason, !reason.isEmpty {
                    infoRow(icon: "text.quote", label: "Motivo", value: reason)
                }
                if let notes = adjustment.notes, !notes.isEmpty {
                    infoRow(icon: "note.text", label: "Notas", value: notes)
                }
                infoRow(icon: "clock", label: "Fecha", value: adjustment.adjustedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .card()
    }

    // MARK: - Quantity

    private func quantityCard(_ detail: BatchDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            cardTitle("Existencia", systemImage: "chart.bar.fill", color: .indigo)

            Divider()

            // An old lot may report original 0; never let the bar's total be 0.
            ProgressView(value: Double(detail.quantity), total: Double(max(detail.originalQuantity, detail.quantity, 1))) {
                Text("\(detail.quantity) de \(detail.originalQuantity) restantes")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } currentValueLabel: {
                Text("\(detail.totalConsumed) salieron")
                    .font(.caption)
            }
        }
        .card()
    }

    // MARK: - History (newest first)

    private func historyCard(_ detail: BatchDetail) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                cardTitle("Movimientos", systemImage: "list.bullet.rectangle", color: .blue)
                Spacer()
                Text("\(detail.consumptionCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if detail.consumptions.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos",
                    systemImage: "tray",
                    description: Text("Ninguna venta ni ajuste ha tomado piezas de este lote.")
                )
            } else {
                let rows = Array(detail.consumptions.reversed())
                ForEach(rows) { consumption in
                    historyRow(consumption)
                    if consumption.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .card()
    }

    private func historyRow(_ consumption: BatchConsumption) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: consumption.typeIcon)
                .font(.caption)
                .foregroundStyle(consumption.typeTone.color)
                .frame(width: DS.Spacing.xl)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(consumption.typeLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                    if let sale = consumption.sale {
                        Text("#\(sale.squareId.suffix(6))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(consumption.consumedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(StockImpact(before: nil, change: -consumption.quantity)?.changeText ?? "\(consumption.quantity)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(consumption.formattedTotalCost)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func cardTitle(_ title: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(title).font(.headline)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(color)
        }
    }

    private func metricBox(value: String, label: String, tone: Tone) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(.headline)
                .foregroundStyle(tone == .neutral ? Color.primary : tone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.s)
        .background(.fill.tertiary, in: .rect(cornerRadius: DS.Radius.m))
    }

    private func infoRow(icon: String, label: String, value: String, color: Color = .secondary) -> some View {
        LabeledContent {
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        } label: {
            Label {
                Text(label).foregroundStyle(.secondary)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
        }
        .font(.caption)
    }
}

// MARK: - Batch Detail ViewModel

@MainActor
class BatchDetailViewModel: ObservableObject {
    @Published var batchDetail: BatchDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    func loadBatchDetail(batchId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: BatchDetailResponse = try await apiClient.request(
                endpoint: .batchDetail(batchId: batchId)
            )
            batchDetail = response.data
        } catch {
            print("Failed to load batch detail: \(error)")
            errorMessage = error.localizedDescription
            batchDetail = nil
        }
    }
}

// MARK: - Preview

#Preview {
    BatchDetailView(batchId: "test-batch-1", productName: "Paracetamol 500mg")
}
