import SwiftUI

// MARK: - Profit & Loss Report View

struct ProfitLossReportView: View {
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
                } else if let report = viewModel.profitLossReport {
                    VStack(spacing: 0) {
                        // Revenue Section
                        PLSection(title: "Ingresos", color: .green) {
                            PLRow(label: "Total de Ventas", value: report.revenue.sales, isTotal: false)
                            PLRow(label: "Ingresos Totales", value: report.revenue.total, isTotal: true)
                        }

                        // COGS Section
                        PLSection(title: "Costo de Mercancía Vendida", color: .red) {
                            PLRow(label: "Costos de Productos", value: report.costOfGoodsSold.productCosts, isTotal: false, isNegative: true)
                            PLRow(label: "Costo Total de Ventas", value: report.costOfGoodsSold.total, isTotal: true, isNegative: true)
                        }

                        // Gross Profit
                        PLSummaryRow(
                            label: "Ganancia Bruta",
                            value: report.grossProfit.amount,
                            subtitle: "\(formatPercent(report.grossProfit.marginPercent)) margin",
                            color: .blue
                        )

                        // Operating Expenses
                        PLSection(title: "Gastos Operativos", color: .orange) {
                            ForEach(report.operatingExpenses.byType, id: \.type) { expense in
                                PLRow(label: ExpenseType(rawValue: expense.type)?.displayName ?? expense.type, value: expense.amount, isTotal: false, isNegative: true)
                            }
                            PLRow(label: "Merma", value: report.operatingExpenses.shrinkage, isTotal: false, isNegative: true)
                            PLRow(label: "Total de Gastos", value: report.operatingExpenses.total, isTotal: true, isNegative: true)
                        }

                        // Net Profit
                        PLSummaryRow(
                            label: "Ganancia Neta",
                            value: report.netProfit.amount,
                            subtitle: "\(formatPercent(report.netProfit.marginPercent)) margin",
                            color: Double(report.netProfit.amount) ?? 0 >= 0 ? .green : .red
                        )
                    }
                    .padding(.horizontal)
                } else {
                    emptyState
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Pérdidas y Ganancias")
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
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos de P&G")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadProfitLossReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct PLSection<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .padding(.top, 12)

            VStack(spacing: 4) {
                content()
            }
        }
    }
}

struct PLRow: View {
    let label: String
    let value: String
    let isTotal: Bool
    var isNegative: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .subheadline.bold() : .subheadline)

            Spacer()

            Text(isNegative ? "(\(formatCurrency(value)))" : formatCurrency(value))
                .font(isTotal ? .subheadline.bold() : .subheadline)
                .foregroundStyle(isNegative ? Color.red : Color.primary)
        }
        .padding(.vertical, 4)
    }
}

struct PLSummaryRow: View {
    let label: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(value))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.vertical, 8)
    }
}
