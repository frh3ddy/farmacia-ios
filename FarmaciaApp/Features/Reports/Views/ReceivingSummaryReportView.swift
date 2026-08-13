import SwiftUI

// MARK: - Receiving Summary Report View

struct ReceivingSummaryReportView: View {
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
                } else if let report = viewModel.receivingSummaryReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Costo Total",
                            value: formatCurrency(report.summary.totalCost),
                            color: .green
                        )

                        ReportHeaderCard(
                            title: "Cantidad Total",
                            value: "\(report.summary.totalQuantity)",
                            color: .blue
                        )

                        ReportHeaderCard(
                            title: "Recepciones",
                            value: "\(report.summary.totalReceivings)",
                            color: .purple
                        )

                        ReportHeaderCard(
                            title: "Costo Prom.",
                            value: formatCurrency(report.summary.averageCostPerUnit),
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // By Supplier
                    if let suppliers = report.bySupplier, !suppliers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Proveedor")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(suppliers) { supplier in
                                SupplierReceivingRow(supplier: supplier)
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
                                ProductReceivingRow(product: product)
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
        .navigationTitle("Resumen de Recepciones")
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
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos de recepciones")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadReceivingSummaryReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct SupplierReceivingRow: View {
    let supplier: SupplierReceivingSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(supplier.supplierName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(supplier.receivingCount) recepciones • \(supplier.totalQuantity) uds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(supplier.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}

struct ProductReceivingRow: View {
    let product: ProductReceivingSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(product.receivingCount) recepciones • \(product.totalQuantity) units @ \(formatCurrency(product.averageCost))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(product.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}
