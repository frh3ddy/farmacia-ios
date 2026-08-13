import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var stockAlertViewModel = StockAlertViewModel()
    @StateObject private var signalsViewModel = ActionableSignalsViewModel()
    @StateObject private var expiringViewModel = DashboardExpiringViewModel()
    @State private var showShoppingListCreated = false
    @State private var createdListName = ""
    
    private var shoppingListStore: ShoppingListStore { ShoppingListStore.shared }
    
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
                    
                    // Stock Alert Card
                    if stockAlertViewModel.needsAttention {
                        stockAlertCard
                    }
                    
                    // Expiring Products Alert
                    if expiringViewModel.hasExpiringProducts {
                        expiringAlertCard
                    }
                    
                    // Actionable Signals (from aging service)
                    if !signalsViewModel.signals.isEmpty {
                        actionableSignalsSection
                    }
                    
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
                // Fire all dashboard loads in parallel — they are independent
                async let dashboardLoad: () = viewModel.loadDashboard()
                async let alertsLoad: () = loadStockAlerts()
                async let signalsLoad: () = loadSignals()
                async let expiringLoad: () = loadExpiringData()
                _ = await (dashboardLoad, alertsLoad, signalsLoad, expiringLoad)
            }
        }
    }
    
    private func loadStockAlerts() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await stockAlertViewModel.loadProducts(locationId: locationId)
    }
    
    private func loadSignals() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await signalsViewModel.loadSignals(locationId: locationId)
    }
    
    private func loadExpiringData() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await expiringViewModel.loadExpiring(locationId: locationId)
    }
    
    // MARK: - Stock Alert Card
    
    private var stockAlertCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                Text("Alertas de Inventario")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink {
                    // Navigate to Products tab (via MainTabView)
                    // For now, link to a filtered products view
                    StockAlertProductsView(products: stockAlertViewModel.products)
                } label: {
                    Text("Ver Productos")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }
            
            Divider()
            
            HStack(spacing: 16) {
                if stockAlertViewModel.outOfStockCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.outOfStockCount)",
                        label: "Sin Stock",
                        color: .red
                    )
                }
                
                if stockAlertViewModel.lowStockCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.lowStockCount)",
                        label: "Stock Bajo",
                        color: .orange
                    )
                }
                
                if stockAlertViewModel.lowMarginCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.lowMarginCount)",
                        label: "Margen Bajo",
                        color: .purple
                    )
                }
                
                Spacer()
            }
            
            // Create Shopping List action
            Divider()
            
            Button {
                createRestockShoppingList()
            } label: {
                HStack {
                    Image(systemName: "list.clipboard")
                    Text("Crear Lista de Reabasto")
                    Spacer()
                    Text("\(stockAlertViewModel.outOfStockCount + stockAlertViewModel.lowStockCount) artículos")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .alert("Lista de Compras Creada", isPresented: $showShoppingListCreated) {
            Button("OK") {}
        } message: {
            Text("\"\(createdListName)\" ha sido creada con artículos que necesitan reabasto. Abre Listas de Compras desde la pestaña de Productos para revisar.")
        }
    }
    
    private func alertMetric(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
    
    // MARK: - Expiring Products Alert Card
    
    private var expiringAlertCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .font(.title3)
                
                Text("Productos por Vencer")
                    .font(.headline)
                
                Spacer()
                
                if let summary = expiringViewModel.summary {
                    Text("$\(String(format: "%.0f", summary.totalCashAtRisk)) en riesgo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(.rect(cornerRadius: 6))
                }
            }
            
            Divider()
            
            if let summary = expiringViewModel.summary {
                HStack(spacing: 16) {
                    if summary.totalExpiredBatches > 0 {
                        alertMetric(
                            value: "\(summary.totalExpiredBatches)",
                            label: "Vencidos",
                            color: .red
                        )
                    }
                    if summary.criticalCount > 0 {
                        alertMetric(
                            value: "\(summary.criticalCount)",
                            label: "Crítico",
                            color: .red
                        )
                    }
                    if summary.highCount > 0 {
                        alertMetric(
                            value: "\(summary.highCount)",
                            label: "Por Vencer",
                            color: .orange
                        )
                    }
                    alertMetric(
                        value: "\(summary.totalProducts)",
                        label: "Productos",
                        color: .secondary
                    )
                    Spacer()
                }
            }
            
            // Top 3 expiring products
            ForEach(expiringViewModel.products.prefix(3)) { product in
                HStack(spacing: 8) {
                    Image(systemName: product.severityIcon)
                        .font(.caption)
                        .foregroundStyle(product.severityColor)
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(product.productName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("\(product.totalUnits) unidades")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if product.expiredCount > 0 {
                                Text("\u{2022} \(product.expiredCount) vencidos")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            } else {
                                Text("\u{2022} vence \(product.soonestExpiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(product.formattedCashAtRisk)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Shopping List Creation Helpers
    
    private func createRestockShoppingList() {
        let outOfStock = stockAlertViewModel.products.filter { ($0.totalInventory ?? 0) == 0 }
        let lowStock = stockAlertViewModel.products.filter {
            let inv = $0.totalInventory ?? 0
            return inv > 0 && inv < 10
        }
        
        let dateSuffix = Date().formatted(date: .abbreviated, time: .omitted)
        let name = "Reabasto \(dateSuffix)"
        
        var list = ShoppingList(
            name: name,
            locationId: authManager.currentLocation?.id,
            locationName: authManager.currentLocation?.name
        )
        
        for product in outOfStock {
            let reorderTarget = 10
            let item = ShoppingListItem(
                productId: product.id,
                productName: product.displayName,
                sku: product.sku,
                plannedQuantity: reorderTarget,
                unitCost: product.averageCost ?? 0,
                previousCost: product.averageCost
            )
            list.addItem(item)
        }
        for product in lowStock {
            let stock = product.totalInventory ?? 0
            let reorderTarget = 10
            let suggestedQty = max(1, reorderTarget - stock)
            let item = ShoppingListItem(
                productId: product.id,
                productName: product.displayName,
                sku: product.sku,
                plannedQuantity: suggestedQty,
                unitCost: product.averageCost ?? 0,
                previousCost: product.averageCost
            )
            list.addItem(item)
        }
        
        shoppingListStore.save(list)
        createdListName = name
        showShoppingListCreated = true
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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

// MARK: - Actionable Signals Section (in DashboardView)

extension DashboardView {
    var actionableSignalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.title3)
                
                Text("Acción Requerida")
                    .font(.headline)
                
                Spacer()
                
                if signalsViewModel.signals.count > 3 {
                    NavigationLink {
                        AllSignalsView(signals: signalsViewModel.signals)
                    } label: {
                        Text("Ver Todos (\(signalsViewModel.signals.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }
            
            Divider()
            
            // Show up to 3 signals
            ForEach(signalsViewModel.signals.prefix(3)) { signal in
                signalRow(signal)
                
                if signal.id != signalsViewModel.signals.prefix(3).last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func signalRow(_ signal: ActionableSignal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Signal type icon
                Image(systemName: signal.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(signal.severity.color)
                    .frame(width: 28, height: 28)
                    .background(signal.severity.color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.entityName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(signal.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Severity + cash badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(signal.severity.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signal.severity.color.opacity(0.15))
                        .foregroundStyle(signal.severity.color)
                        .clipShape(.rect(cornerRadius: 4))
                    
                    if let cash = signal.formattedCashAtRisk {
                        Text(cash)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Recommended actions (compact)
            if !signal.recommendedActions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(signal.recommendedActions.prefix(2), id: \.self) { action in
                        Text(action)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.secondary)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                    
                    if signal.recommendedActions.count > 2 {
                        Text("+\(signal.recommendedActions.count - 2)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AuthManager.shared)
}
