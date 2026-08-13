import SwiftUI

// MARK: - Expense Summary Report View

struct ExpenseSummaryReportView: View {
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
                } else if let summary = viewModel.expenseSummary {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Total de Gastos",
                            value: formatCurrency(summary.totalExpenses),
                            color: .red
                        )

                        ReportHeaderCard(
                            title: "Cantidad de Gastos",
                            value: "\(summary.expenseCount)",
                            color: .blue
                        )

                        ReportHeaderCard(
                            title: "Pagado",
                            value: formatCurrency(summary.paidExpenses),
                            color: .green
                        )

                        ReportHeaderCard(
                            title: "No Pagado",
                            value: formatCurrency(summary.unpaidExpenses),
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // By Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Por Tipo")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(summary.byType, id: \.type) { typeSummary in
                            ExpenseTypeRow(typeSummary: typeSummary)
                        }
                    }
                    .padding(.top)

                    // By Month
                    if let byMonth = summary.byMonth, !byMonth.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Por Mes")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(byMonth, id: \.month) { month in
                                MonthlyExpenseRow(month: month)
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
        .navigationTitle("Resumen de Gastos")
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
            Image(systemName: "creditcard")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("No hay datos de gastos")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadReport() {
        Task {
            await viewModel.loadExpenseSummary(locationId: authManager.currentLocation?.id)
        }
    }
}

struct ExpenseTypeRow: View {
    let typeSummary: ExpenseTypeSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(typeSummary.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(typeSummary.count) gastos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(typeSummary.total))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatPercent(typeSummary.percentage))
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

struct MonthlyExpenseRow: View {
    let month: MonthlyExpenseSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(month.month)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(month.count) gastos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(month.total))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(.rect(cornerRadius: 8))
        .padding(.horizontal)
    }
}
