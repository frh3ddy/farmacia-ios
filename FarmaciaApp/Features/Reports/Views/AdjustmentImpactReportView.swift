import SwiftUI

// MARK: - Adjustment Impact Report View

struct AdjustmentImpactReportView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ReportsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date Range
                DateRangePicker(
                    startDate: $viewModel.startDate,
                    endDate: $viewModel.endDate
                ) {
                    loadReport()
                }
                .padding(.horizontal)

                if viewModel.isLoading {
                    ProgressView("Cargando...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.adjustmentImpactReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Pérdida Total",
                            value: formatCurrency(report.summary.totalLoss),
                            color: .red
                        )

                        ReportHeaderCard(
                            title: "Valor Repuesto",
                            value: formatCurrency(report.summary.totalGain),
                            subtitle: "Se refleja al vender",
                            color: .green
                        )

                        ReportHeaderCard(
                            title: "Diferencia Neta",
                            value: formatCurrency(report.summary.netImpact),
                            subtitle: "Referencia, no es Ganancia Neta",
                            color: Double(report.summary.netImpact) ?? 0 >= 0 ? .green : .red
                        )

                        ReportHeaderCard(
                            title: "Ajustes",
                            value: "\(report.summary.totalAdjustments)",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    Text("Solo la Pérdida Total se refleja de inmediato en la Ganancia Neta. El Valor Repuesto se refleja hasta que ese inventario se vende.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // By Type
                    if !report.byType.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Tipo")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(report.byType) { typeImpact in
                                AdjustmentTypeRow(impact: typeImpact)
                            }
                        }
                        .padding(.top)
                    }

                    // By Product
                    if let products = report.byProduct, !products.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Producto")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(products) { product in
                                ProductAdjustmentRow(product: product)
                            }
                        }
                        .padding(.top)
                    }
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Impacto de Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Ocurrió un error")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos de ajustes")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadAdjustmentImpactReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct AdjustmentTypeRow: View {
    let impact: AdjustmentTypeImpact

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(AdjustmentType(rawValue: impact.type)?.displayName ?? impact.type)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(impact.count) ajustes • \(impact.totalQuantity) uds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(impact.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}

struct ProductAdjustmentRow: View {
    let product: ProductAdjustmentImpact

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(product.adjustmentCount) ajustes • \(product.totalQuantity) uds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if Double(product.totalLoss) ?? 0 > 0 {
                    Text("-\(formatCurrency(product.totalLoss))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if Double(product.totalGain) ?? 0 > 0 {
                    Text("+\(formatCurrency(product.totalGain))")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Text(formatCurrency(product.netImpact))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Double(product.netImpact) ?? 0 >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}
