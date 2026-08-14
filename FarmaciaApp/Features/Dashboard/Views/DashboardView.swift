import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
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
                    
                    // Quick Stats
                    if let report = viewModel.dashboardReport {
                        quickStatsSection(report: report)
                        
                        // Sales Summary
                        salesSummarySection(report: report)
                        
                        // Inventory Overview
                        inventorySummarySection(report: report)
                        
                        // Receivings Summary
                        recepcionesSummarySection(report: report)
                        
                        // Recent Adjustments
                        ajustesSummarySection(report: report)
                        
                        // P&L Summary
                        if authManager.canViewReports {
                            profitLossSummarySection(report: report)
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
            .onChange(of: authManager.currentLocation?.id) { oldId, newId in
                // Refresh dashboard when location changes
                if oldId != nil && newId != nil && oldId != newId {
                    Task {
                        await viewModel.loadDashboard()
                    }
                }
            }
            .task {
                await viewModel.loadDashboard()
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
            
            Picker("Rango de Fechas", selection: $viewModel.selectedDateRange) {
                ForEach(DashboardDateRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedDateRange) { _, _ in
                Task {
                    await viewModel.loadDashboard()
                }
            }
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.loadDashboard()
                }
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
            
            StatCard(
                title: "Ganancia Bruta",
                value: formatCurrency(report.sales.grossProfit),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
            
            StatCard(
                title: "Valor de Inventario",
                value: formatCurrency(report.inventory.totalValue),
                icon: "shippingbox.fill",
                color: .orange
            )
            
            StatCard(
                title: "Ganancia Neta",
                value: formatCurrency(report.netProfit.amount),
                icon: "banknote.fill",
                color: (Double(report.netProfit.amount) ?? 0) >= 0 ? .green : .red
            )
        }
    }
    
    // MARK: - Sales Summary Section
    
    private func salesSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Resumen de Ventas", icon: "cart.fill")
            
            VStack(spacing: 8) {
                summaryRow(label: "Ingresos Totales", value: formatCurrency(report.sales.totalRevenue))
                summaryRow(label: "Costo de Ventas", value: formatCurrency(report.sales.totalCOGS))
                summaryRow(label: "Ganancia Bruta", value: formatCurrency(report.sales.grossProfit), valueColor: .green)
                summaryRow(label: "Margen Bruto", value: "\(report.sales.grossMarginPercent)%")
                
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
                        Text("Total Ventas")
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
            sectionHeader(title: "Inventario", icon: "shippingbox")
            
            VStack(spacing: 8) {
                summaryRow(label: "Unidades Totales", value: "\(report.inventory.totalUnits)")
                summaryRow(label: "Valor Total", value: formatCurrency(report.inventory.totalValue))
                summaryRow(label: "Productos", value: "\(report.inventory.totalProducts)")
                summaryRow(label: "Costo Prom/Unidad", value: formatCurrency(report.inventory.averageCostPerUnit))
                
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
    
    private func recepcionesSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Recepciones", icon: "arrow.down.circle")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Recepciones", value: "\(report.recepciones.totalReceivings)")
                summaryRow(label: "Unidades Recibidas", value: "\(report.recepciones.totalQuantity)")
                summaryRow(label: "Costo Total", value: formatCurrency(report.recepciones.totalCost))
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
    
    // MARK: - Adjustments Summary Section
    
    private func ajustesSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Ajustes", icon: "arrow.up.arrow.down")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Ajustes", value: "\(report.ajustes.totalAdjustments)")
                summaryRow(label: "Pérdida Total", value: formatCurrency(report.ajustes.totalLoss), valueColor: .red)
                summaryRow(label: "Ganancia Total", value: formatCurrency(report.ajustes.totalGain), valueColor: .green)
                
                Divider()
                
                HStack {
                    Text("Impacto Neto")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatCurrency(report.ajustes.netImpact))
                        .fontWeight(.bold)
                        .foregroundStyle((Double(report.ajustes.netImpact) ?? 0) >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
    
    // MARK: - Profit & Loss Summary Section
    
    private func profitLossSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Pérdidas y Ganancias", icon: "chart.pie.fill")
            
            VStack(spacing: 8) {
                summaryRow(label: "Ingresos", value: formatCurrency(report.sales.totalRevenue), valueColor: .green)
                summaryRow(label: "Costo de Ventas", value: "(\(formatCurrency(report.sales.totalCOGS)))", valueColor: .red)
                summaryRow(label: "Gastos Operativos", value: "(\(formatCurrency(report.operatingExpenses.total)))", valueColor: .red)
                summaryRow(label: "Merma", value: "(\(formatCurrency(report.operatingExpenses.shrinkage)))", valueColor: .orange)
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ganancia Neta")
                            .fontWeight(.semibold)
                        Text("\(report.netProfit.marginPercent)% margen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(report.netProfit.amount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle((Double(report.netProfit.amount) ?? 0) >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 12))
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
                Task {
                    await viewModel.loadDashboard()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
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
                Label(authManager.currentEmployee?.role.rawValue ?? "", systemImage: "briefcase")
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
            Text(String(authManager.currentEmployee?.name.prefix(2).uppercased() ?? "??"))
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
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
