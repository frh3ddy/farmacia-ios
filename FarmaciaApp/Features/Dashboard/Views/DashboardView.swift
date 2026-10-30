import SwiftUI
import FarmaciaKit

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            // Vertical axis locked explicitly; containerRelativeFrame clamps
            // the content width to the viewport so long dynamic values
            // (e.g. large currency amounts in summary/P&L rows) can wrap or
            // compress instead of stretching the content and enabling
            // horizontal panning — matches the List behavior in ProductsView
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    // Welcome Header
                    welcomeHeader

                    // Date Range Selector
                    dateRangeSelector
                    
                    // A refresh of this same selection failed; its earlier numbers are still on screen
                    if viewModel.visibleReport != nil, let error = viewModel.error {
                        staleDataBanner(error: error)
                    }
                    
                    // Quick Stats
                    if let report = viewModel.visibleReport {
                        quickStatsSection(report: report)
                        
                        // Sales Summary
                        salesSummarySection(report: report)
                        
                        // Inventory Overview
                        inventorySummarySection(report: report)
                        
                        // Receivings Summary
                        receivingsSummarySection(report: report)

                        // Recent Adjustments
                        adjustmentsSummarySection(report: report)
                        
                        // P&L Summary
                        if let expenses = report.operatingExpenses, let netProfit = report.netProfit {
                            profitLossSummarySection(report: report, expenses: expenses, netProfit: netProfit)
                        }
                    } else if viewModel.isLoading {
                        loadingSection
                    } else if let error = viewModel.error {
                        errorSection(error: error)
                    }
                }
                .padding()
                .containerRelativeFrame(.horizontal)
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
            .navigationTitle("Inicio")
            .toolbar {
                // Location switcher
                ToolbarItem(placement: .topBarLeading) {
                    locationButton
                }
                
                // User info
                ToolbarItem(placement: .topBarTrailing) {
                    userButton
                }
            }
            .sheet(isPresented: $viewModel.showLocationSwitcher) {
                LocationSwitchView()
            }
            // One load at a time: a new period, location or reload cancels the running
            // one, so a slow earlier response can't replace the newer selection.
            .task(id: DashboardLoadKey(
                selection: DashboardSelection(
                    period: viewModel.selectedPeriod,
                    locationId: authManager.currentLocation?.id,
                    day: viewModel.today
                ),
                reloadID: viewModel.reloadID
            )) {
                await viewModel.loadDashboard()
            }
            // Back from the background on a new day: "Hoy" and the other periods move with it
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let today = LocalDay.string(from: Date())
                if viewModel.today != today { viewModel.today = today }
            }
        }
    }

    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bienvenido,")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(authManager.currentEmployee?.name ?? "Usuario")
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.blue)
                Text(authManager.currentLocation?.name ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 16))
    }
    
    // MARK: - Date Range Selector
    
    private var dateRangeSelector: some View {
        HStack {
            Text("Período:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Rango de Fechas", selection: $viewModel.selectedPeriod) {
                ForEach(DashboardPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.menu)
            
            Spacer()
            
            Button {
                viewModel.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Actualizar")
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Stats Section
    
    private func quickStatsSection(report: DashboardReport) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Ingresos",
                value: formatCurrency(report.sales.totalRevenue),
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            // Cost-based cards only when the server sent costs (never to a cashier)
            if let grossProfit = report.sales.grossProfit {
                StatCard(
                    title: "Ganancia Bruta",
                    value: formatCurrency(grossProfit),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
            } else {
                StatCard(
                    title: "Núm. de Ventas",
                    value: report.sales.totalSales.formatted(),
                    icon: "cart.fill",
                    color: .blue
                )
            }
            
            if let totalValue = report.inventory.totalValue {
                StatCard(
                    title: "Valor de Inventario",
                    value: formatCurrency(totalValue),
                    icon: "shippingbox.fill",
                    color: .orange
                )
            } else {
                StatCard(
                    title: "Unidades Vendidas",
                    value: report.sales.totalUnitsSold.formatted(),
                    icon: "bag.fill",
                    color: .orange
                )
                StatCard(
                    title: "Unidades en Inventario",
                    value: report.inventory.totalUnits.formatted(),
                    icon: "shippingbox.fill",
                    color: .purple
                )
            }
            
            if let netProfit = report.netProfit {
                StatCard(
                    title: "Ganancia Neta",
                    value: formatCurrency(netProfit.amount),
                    icon: "banknote.fill",
                    color: ReportFormat.isNonNegative(netProfit.amount) ? .green : .red
                )
            }
        }
    }
    
    // MARK: - Sales Summary Section
    
    private func salesSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Resumen de Ventas", icon: "cart.fill")
            
            VStack(spacing: 8) {
                summaryRow(label: "Ingresos Totales", value: formatCurrency(report.sales.totalRevenue))
                if let cost = report.sales.totalCOGS {
                    summaryRow(label: "Costo de Ventas", value: formatCurrency(cost))
                }
                if let grossProfit = report.sales.grossProfit {
                    summaryRow(label: "Ganancia Bruta", value: formatCurrency(grossProfit),
                               valueColor: ReportFormat.isNonNegative(grossProfit) ? .green : .red)
                }
                if let margin = report.sales.grossMarginPercent {
                    summaryRow(label: "Margen Bruto", value: ReportFormat.percent(margin))
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Unidades Vendidas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(report.sales.totalUnitsSold)")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Núm. de Ventas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(report.sales.totalSales)")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
    
    // MARK: - Inventory Summary Section
    
    private func inventorySummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                sectionHeader(title: "Inventario actual", icon: "shippingbox")
                // Inventory is always as of now; the period picker doesn't apply
                Text("Al día de hoy, no del período")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                summaryRow(label: "Unidades Totales", value: "\(report.inventory.totalUnits)")
                if let totalValue = report.inventory.totalValue {
                    summaryRow(label: "Valor Total", value: formatCurrency(totalValue))
                }
                summaryRow(label: "Productos", value: "\(report.inventory.totalProducts)")
                if let averageCost = report.inventory.averageCostPerUnit {
                    summaryRow(label: "Costo Prom/Unidad", value: formatCurrency(averageCost))
                }
                
                // Aging breakdown if available
                if let aging = report.inventory.aging {
                    Divider()
                    
                    Text("Antigüedad del Inventario")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 8) {
                        agingBadge(label: "<30d", count: aging.under30Days.units, color: .green)
                        agingBadge(label: "30-60d", count: aging.days30to60.units, color: .blue)
                        agingBadge(label: "60-90d", count: aging.days60to90.units, color: .orange)
                        agingBadge(label: ">90d", count: aging.over90Days.units, color: .red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
    
    // MARK: - Receivings Summary Section
    
    private func receivingsSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recepciones", icon: "arrow.down.circle")

            VStack(spacing: 8) {
                summaryRow(label: "Total Recepciones", value: "\(report.receivings.totalReceivings)")
                summaryRow(label: "Unidades Recibidas", value: "\(report.receivings.totalQuantity)")
                if let totalCost = report.receivings.totalCost {
                    summaryRow(label: "Costo Total", value: formatCurrency(totalCost))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    // MARK: - Adjustments Summary Section

    private func adjustmentsSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Ajustes", icon: "arrow.up.arrow.down")

            VStack(spacing: 8) {
                summaryRow(label: "Total Ajustes", value: "\(report.adjustments.totalAdjustments)")
                // Losses and gains are valued at cost: not sent to a cashier
                if let totalLoss = report.adjustments.totalLoss {
                    summaryRow(label: "Pérdida Total", value: formatCurrency(totalLoss), valueColor: .red)
                }
                if let totalGain = report.adjustments.totalGain {
                    summaryRow(label: "Ganancia Total", value: formatCurrency(totalGain), valueColor: .green)
                }

                if let netImpact = report.adjustments.netImpact {
                    Divider()

                    HStack {
                        Text("Impacto Neto")
                            .fontWeight(.medium)
                        Spacer()
                        Text(formatCurrency(netImpact))
                            .fontWeight(.bold)
                            .foregroundStyle(ReportFormat.isNonNegative(netImpact) ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
    
    // MARK: - Profit & Loss Summary Section
    
    private func profitLossSummarySection(report: DashboardReport, expenses: OperatingExpensesSummary, netProfit: NetProfitSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Pérdidas y Ganancias", icon: "chart.pie.fill")
            
            // Rows from the same P&L as net profit (merma once, Yastás shown), so they
            // add up to it; item-summed sales are only the fallback for older servers.
            let pl = ProfitLossLines(
                netProfit: netProfit,
                itemRevenue: report.sales.totalRevenue,
                itemCost: report.sales.totalCOGS ?? "",
                operatingExpensesTotal: expenses.total,
                shrinkage: expenses.shrinkage
            )
            VStack(spacing: 8) {
                ForEach(pl.lines.filter { $0.kind != .total }, id: \.label) { line in
                    switch line.kind {
                    case .income:
                        summaryRow(label: line.label, value: formatCurrency(line.amount), valueColor: .green)
                    case .shrinkage:
                        summaryRow(label: line.label, value: "(\(formatCurrency(line.amount)))", valueColor: .orange)
                    case .cost, .total:
                        summaryRow(label: line.label, value: "(\(formatCurrency(line.amount)))", valueColor: .red)
                    }
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ganancia Neta")
                            .fontWeight(.semibold)
                        Text("\(ReportFormat.percent(netProfit.marginPercent)) margen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(netProfit.amount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(ReportFormat.isNonNegative(netProfit.amount) ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
            #if DEBUG
            .onAppear {
                // The server's net profit is shown either way; this flags a contract drift.
                if !pl.addsUp { print("[Dashboard] P&L rows don't add up to net profit \(netProfit.amount)") }
            }
            #endif
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Cargando...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }
    
    // MARK: - Error Section
    
    private func errorSection(error: NetworkError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            Text("Error al cargar el panel")
                .font(.headline)
            
            Text(error.errorDescription ?? "Error desconocido")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Reintentar") {
                viewModel.reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
    
    // MARK: - Stale Data Banner
    
    private func staleDataBanner(error: NetworkError) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("No se pudo actualizar. Mostrando los datos anteriores.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(error.errorDescription ?? "Error desconocido")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Under the text, not beside it, so large Dynamic Type sizes keep a readable width
                Button("Reintentar") {
                    viewModel.reload()
                }
                .font(.subheadline)
                .padding(.top, 4)
            }
            
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
    }
    
    // MARK: - Toolbar Buttons
    
    private var locationButton: some View {
        Button {
            viewModel.showLocationSwitcher = true
        } label: {
            HStack(spacing: 6) {
                // Location icon with subtle pulse when loading
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(authManager.currentLocation?.name ?? "Ubicación")
                        .lineLimit(1)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let role = authManager.currentLocation?.role {
                        Text(role.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var userButton: some View {
        Menu {
            Section {
                Label(authManager.currentEmployee?.name ?? "Usuario", systemImage: "person")
                Label(authManager.currentEmployee?.role.displayName ?? "", systemImage: "briefcase")
            }
            
            Divider()
            
            Button {
                Task {
                    await authManager.logout()
                }
            } label: {
                Label("Cerrar Sesión", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Text(authManager.currentEmployee?.initials ?? "??")
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
        .accessibilityLabel(authManager.currentEmployee?.name ?? "Usuario")
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
        }
    }
    
    private func summaryRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .font(.subheadline)
    }
    
    private func agingBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(.rect(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AuthManager.shared)
}
