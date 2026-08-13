import SwiftUI

// MARK: - COGS Report View

struct COGSReportView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ReportsViewModel()
    @State private var showDatePicker = false

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
                } else if let report = viewModel.cogsReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Costo Total de Ventas",
                            value: formatCurrency(report.summary.totalCOGS),
                            color: .red
                        )

                        ReportHeaderCard(
                            title: "Ingresos",
                            value: formatCurrency(report.summary.totalRevenue),
                            color: .green
                        )

                        ReportHeaderCard(
                            title: "Ganancia Bruta",
                            value: formatCurrency(report.summary.grossProfit),
                            color: .blue
                        )

                        ReportHeaderCard(
                            title: "Margen",
                            value: formatPercent(report.summary.grossMarginPercent),
                            color: .purple
                        )

                        ReportHeaderCard(
                            title: "Unidades Vendidas",
                            value: "\(report.summary.totalUnitsSold)",
                            color: .orange
                        )

                        ReportHeaderCard(
                            title: "Total de Ventas",
                            value: "\(report.summary.totalSales)",
                            color: .teal
                        )
                    }
                    .padding(.horizontal)

                    // By Product
                    if !report.byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Producto")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(report.byProduct, id: \.productId) { product in
                                ProductCOGSRow(product: product)
                            }
                        }
                        .padding(.top)
                    }

                    // By Category
                    if let categories = report.byCategory, !categories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Categoría")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(categories, id: \.categoryName) { category in
                                CategoryCOGSRow(category: category)
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
        .navigationTitle("Costo de Mercancía Vendida")
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
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos disponibles")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadCOGSReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct ProductCOGSRow: View {
    let product: ProductCOGS

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
                Text(formatCurrency(product.totalCost))
                    .font(.subheadline)
                    .fontWeight(.semibold)

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

struct CategoryCOGSRow: View {
    let category: CategoryCOGS

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.categoryName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Ganancia: \(formatCurrency(category.grossProfit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(category.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}
