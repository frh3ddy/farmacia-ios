import SwiftUI

// MARK: - Profit Margin Report View

struct ProfitMarginReportView: View {
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
                } else if let report = viewModel.profitMarginReport {
                    // Summary Card
                    ReportHeaderCard(
                        title: "Margen General",
                        value: formatPercent(report.overallMargin),
                        color: .purple
                    )
                    .padding(.horizontal)

                    // By Product
                    if !report.byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Producto")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(report.byProduct, id: \.productId) { product in
                                ProductMarginRow(product: product)
                            }
                        }
                        .padding(.top)
                    }

                    // Trends
                    if let trends = report.trends, !trends.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tendencias")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(trends, id: \.date) { trend in
                                TrendRow(trend: trend)
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
        .navigationTitle("Margen de Ganancia")
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
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos de margen")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadProfitMarginReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct ProductMarginRow: View {
    let product: ProductProfitMargin

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(product.unitsSold) uds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(product.profit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Text(formatPercent(product.marginPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}

struct TrendRow: View {
    let trend: MarginTrend

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Ingresos: \(formatCurrency(trend.revenue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(trend.profit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Double(trend.profit) ?? 0 >= 0 ? .green : .red)

                Text(formatPercent(trend.marginPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}
