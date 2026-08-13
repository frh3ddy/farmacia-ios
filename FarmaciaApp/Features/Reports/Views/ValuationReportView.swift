import SwiftUI

// MARK: - Valuation Report View

struct ValuationReportView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ReportsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Cargando...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.valuationReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Valor Total",
                            value: formatCurrency(report.summary.totalValue),
                            color: .green
                        )

                        ReportHeaderCard(
                            title: "Unidades Totales",
                            value: "\(report.summary.totalUnits)",
                            color: .blue
                        )

                        ReportHeaderCard(
                            title: "Productos",
                            value: "\(report.summary.totalProducts)",
                            color: .purple
                        )

                        ReportHeaderCard(
                            title: "Costo Prom/Unidad",
                            value: formatCurrency(report.summary.averageCostPerUnit),
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // Aging Summary
                    if let aging = report.agingSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resumen de Antigüedad")
                                .font(.headline)
                                .padding(.horizontal)

                            AgingSummaryView(aging: aging)
                        }
                        .padding(.top)
                    }

                    // By Product
                    if !report.byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Producto")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(report.byProduct, id: \.productId) { product in
                                ProductValuationRow(product: product)
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
        .navigationTitle("Valuación de Inventario")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .refreshable { await refreshReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Ocurrió un error")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos de inventario")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadValuationReport(locationId: authManager.currentLocation?.id)
        }
    }

    private func refreshReport() async {
        await viewModel.loadValuationReport(locationId: authManager.currentLocation?.id)
    }
}

struct AgingSummaryView: View {
    let aging: AgingSummary

    var body: some View {
        VStack(spacing: 8) {
            AgingRow(label: "< 30 días", units: aging.under30Days.units, value: aging.under30Days.value, color: .green)
            AgingRow(label: "30-60 días", units: aging.days30to60.units, value: aging.days30to60.value, color: .yellow)
            AgingRow(label: "60-90 días", units: aging.days60to90.units, value: aging.days60to90.value, color: .orange)
            AgingRow(label: "> 90 días", units: aging.over90Days.units, value: aging.over90Days.value, color: .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}

struct AgingRow: View {
    let label: String
    let units: Int
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text("\(units) uds")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatCurrency(value))
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        }
    }
}

struct ProductValuationRow: View {
    let product: ProductValuation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(product.totalQuantity) uds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(product.totalValue))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("@\(formatCurrency(product.averageCost))")
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
