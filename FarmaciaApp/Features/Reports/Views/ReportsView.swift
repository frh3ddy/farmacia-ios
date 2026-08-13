import SwiftUI

// MARK: - Reports View

struct ReportsView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            List {
                // Sales & Profit Reports
                Section("Ventas y Ganancias") {
                    NavigationLink {
                        COGSReportView()
                    } label: {
                        reportRow(
                            title: "Costo de Mercancía Vendida",
                            subtitle: "Seguimiento de costos y ventas",
                            icon: "dollarsign.square",
                            color: .green
                        )
                    }

                    NavigationLink {
                        ProfitMarginReportView()
                    } label: {
                        reportRow(
                            title: "Margen de Ganancia",
                            subtitle: "Análisis de ingresos vs. costos",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        )
                    }

                    NavigationLink {
                        ProfitLossReportView()
                    } label: {
                        reportRow(
                            title: "Pérdidas y Ganancias",
                            subtitle: "Estado completo de P&G",
                            icon: "chart.bar.doc.horizontal",
                            color: .purple
                        )
                    }
                }

                // Inventory Reports
                Section("Inventario") {
                    NavigationLink {
                        ValuationReportView()
                    } label: {
                        reportRow(
                            title: "Valuación de Inventario",
                            subtitle: "Valor actual del inventario",
                            icon: "shippingbox",
                            color: .orange
                        )
                    }

                    NavigationLink {
                        ReceivingSummaryReportView()
                    } label: {
                        reportRow(
                            title: "Resumen de Recepciones",
                            subtitle: "Inventario recibido",
                            icon: "arrow.down.circle",
                            color: .teal
                        )
                    }

                    NavigationLink {
                        AdjustmentImpactReportView()
                    } label: {
                        reportRow(
                            title: "Impacto de Ajustes",
                            subtitle: "Merma y ganancias",
                            icon: "exclamationmark.triangle",
                            color: .red
                        )
                    }
                }

                // Expenses
                if authManager.canManageExpenses {
                    Section("Gastos") {
                        NavigationLink {
                            ExpenseSummaryReportView()
                        } label: {
                            reportRow(
                                title: "Resumen de Gastos",
                                subtitle: "Desglose de gastos operativos",
                                icon: "creditcard",
                                color: .indigo
                            )
                        }
                    }
                }
            }
            .navigationTitle("Reportes")
        }
    }

    private func reportRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    ReportsView()
        .environmentObject(AuthManager.shared)
}
