import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var stockAlertViewModel = StockAlertViewModel()
    @StateObject private var signalsViewModel = ActionableSignalsViewModel()
    @StateObject private var expiringViewModel = DashboardExpiringViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
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
                        receivingsSummarySection(report: report)
                        
                        // Recent Adjustments
                        adjustmentsSummarySection(report: report)
                        
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
            }
            .refreshable {
                await viewModel.loadDashboard()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                // Location switcher
                ToolbarItem(placement: .navigationBarLeading) {
                    locationButton
                }
                
                // User info
                ToolbarItem(placement: .navigationBarTrailing) {
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
                await loadStockAlerts()
                await loadSignals()
                await loadExpiringData()
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
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Inventory Alerts")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink {
                    // Navigate to Products tab (via MainTabView)
                    // For now, link to a filtered products view
                    StockAlertProductsView(products: stockAlertViewModel.products)
                } label: {
                    Text("View Products")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            HStack(spacing: 16) {
                if stockAlertViewModel.outOfStockCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.outOfStockCount)",
                        label: "Out of Stock",
                        color: .red
                    )
                }
                
                if stockAlertViewModel.lowStockCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.lowStockCount)",
                        label: "Low Stock",
                        color: .orange
                    )
                }
                
                if stockAlertViewModel.lowMarginCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.lowMarginCount)",
                        label: "Low Margin",
                        color: .purple
                    )
                }
                
                Spacer()
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
    
    private func alertMetric(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
    
    // MARK: - Expiring Products Alert Card
    
    private var expiringAlertCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Expiring Products")
                    .font(.headline)
                
                Spacer()
                
                if let summary = expiringViewModel.summary {
                    Text("$\(String(format: "%.0f", summary.totalCashAtRisk)) at risk")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                }
            }
            
            Divider()
            
            if let summary = expiringViewModel.summary {
                HStack(spacing: 16) {
                    if summary.totalExpiredBatches > 0 {
                        alertMetric(
                            value: "\(summary.totalExpiredBatches)",
                            label: "Expired",
                            color: .red
                        )
                    }
                    if summary.criticalCount > 0 {
                        alertMetric(
                            value: "\(summary.criticalCount)",
                            label: "Critical",
                            color: .red
                        )
                    }
                    if summary.highCount > 0 {
                        alertMetric(
                            value: "\(summary.highCount)",
                            label: "Expiring Soon",
                            color: .orange
                        )
                    }
                    alertMetric(
                        value: "\(summary.totalProducts)",
                        label: "Products",
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
                        .foregroundColor(product.severityColor)
                        .frame(width: 16)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(product.productName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("\(product.totalUnits) units")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if product.expiredCount > 0 {
                                Text("\u{2022} \(product.expiredCount) expired")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            } else {
                                Text("\u{2022} exp \(product.soonestExpiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text(product.formattedCashAtRisk)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
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
    
    // MARK: - Welcome Header
    
    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back,")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(authManager.currentEmployee?.name ?? "User")
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "building.2")
                    .foregroundColor(.blue)
                Text(authManager.currentLocation?.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Date Range Selector
    
    private var dateRangeSelector: some View {
        HStack {
            Text("Period:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Date Range", selection: $viewModel.selectedDateRange) {
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
                title: "Revenue",
                value: formatCurrency(report.sales.totalRevenue),
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Gross Profit",
                value: formatCurrency(report.sales.grossProfit),
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
            
            StatCard(
                title: "Inventory Value",
                value: formatCurrency(report.inventory.totalValue),
                icon: "shippingbox.fill",
                color: .orange
            )
            
            StatCard(
                title: "Net Profit",
                value: formatCurrency(report.netProfit.amount),
                icon: "banknote.fill",
                color: (Double(report.netProfit.amount) ?? 0) >= 0 ? .green : .red
            )
        }
    }
    
    // MARK: - Sales Summary Section
    
    private func salesSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Sales Summary", icon: "cart.fill")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Revenue", value: formatCurrency(report.sales.totalRevenue))
                summaryRow(label: "Cost of Goods Sold", value: formatCurrency(report.sales.totalCOGS))
                summaryRow(label: "Gross Profit", value: formatCurrency(report.sales.grossProfit), valueColor: .green)
                summaryRow(label: "Gross Margin", value: "\(report.sales.grossMarginPercent)%")
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Units Sold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(report.sales.totalUnitsSold)")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Sales")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(report.sales.totalSales)")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Inventory Summary Section
    
    private func inventorySummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Inventory", icon: "shippingbox")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Units", value: "\(report.inventory.totalUnits)")
                summaryRow(label: "Total Value", value: formatCurrency(report.inventory.totalValue))
                summaryRow(label: "Products", value: "\(report.inventory.totalProducts)")
                summaryRow(label: "Avg Cost/Unit", value: formatCurrency(report.inventory.averageCostPerUnit))
                
                // Aging breakdown if available
                if let aging = report.inventory.aging {
                    Divider()
                    
                    Text("Inventory Age")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
            .cornerRadius(12)
        }
    }
    
    // MARK: - Receivings Summary Section
    
    private func receivingsSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Receivings", icon: "arrow.down.circle")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Receivings", value: "\(report.receivings.totalReceivings)")
                summaryRow(label: "Units Received", value: "\(report.receivings.totalQuantity)")
                summaryRow(label: "Total Cost", value: formatCurrency(report.receivings.totalCost))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Adjustments Summary Section
    
    private func adjustmentsSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Adjustments", icon: "arrow.up.arrow.down")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Adjustments", value: "\(report.adjustments.totalAdjustments)")
                summaryRow(label: "Total Loss", value: formatCurrency(report.adjustments.totalLoss), valueColor: .red)
                summaryRow(label: "Total Gain", value: formatCurrency(report.adjustments.totalGain), valueColor: .green)
                
                Divider()
                
                HStack {
                    Text("Net Impact")
                        .fontWeight(.medium)
                    Spacer()
                    Text(formatCurrency(report.adjustments.netImpact))
                        .fontWeight(.bold)
                        .foregroundColor((Double(report.adjustments.netImpact) ?? 0) >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Profit & Loss Summary Section
    
    private func profitLossSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Profit & Loss", icon: "chart.pie.fill")
            
            VStack(spacing: 8) {
                summaryRow(label: "Revenue", value: formatCurrency(report.sales.totalRevenue), valueColor: .green)
                summaryRow(label: "COGS", value: "(\(formatCurrency(report.sales.totalCOGS)))", valueColor: .red)
                summaryRow(label: "Operating Expenses", value: "(\(formatCurrency(report.operatingExpenses.total)))", valueColor: .red)
                summaryRow(label: "Shrinkage", value: "(\(formatCurrency(report.operatingExpenses.shrinkage)))", valueColor: .orange)
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Net Profit")
                            .fontWeight(.semibold)
                        Text("\(report.netProfit.marginPercent)% margin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(report.netProfit.amount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor((Double(report.netProfit.amount) ?? 0) >= 0 ? .green : .red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading dashboard...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }
    
    // MARK: - Error Section
    
    private func errorSection(error: NetworkError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Failed to load dashboard")
                .font(.headline)
            
            Text(error.errorDescription ?? "Unknown error")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
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
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(authManager.currentLocation?.name ?? "Location")
                        .lineLimit(1)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let role = authManager.currentLocation?.role {
                        Text(role.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var userButton: some View {
        Menu {
            Section {
                Label(authManager.currentEmployee?.name ?? "User", systemImage: "person")
                Label(authManager.currentEmployee?.role.rawValue ?? "", systemImage: "briefcase")
            }
            
            Divider()
            
            Button {
                Task {
                    await authManager.logout()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Text(String(authManager.currentEmployee?.name.prefix(2).uppercased() ?? "??"))
                .font(.caption)
                .fontWeight(.bold)
                .frame(width: 32, height: 32)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
        }
    }
    
    private func summaryRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
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
        .foregroundColor(color)
        .cornerRadius(8)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Date Range Enum

enum DashboardDateRange: CaseIterable {
    case today
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case thisYear
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisYear: return "This Year"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
            
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
            
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            return (start, now)
            
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (start, now)
            
        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart)!
            return (lastMonthStart, lastMonthEnd)
            
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (start, now)
        }
    }
}

// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboardReport: DashboardReport?
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showLocationSwitcher = false
    @Published var selectedDateRange: DashboardDateRange = .last30Days
    
    private let apiClient = APIClient.shared
    
    func loadDashboard() async {
        isLoading = true
        error = nil
        
        do {
            // Get current location
            guard let locationId = AuthManager.shared.currentLocation?.id else {
                error = NetworkError.serverError(message: "No location selected")
                isLoading = false
                return
            }
            
            // Get date range
            let (startDate, endDate) = selectedDateRange.dateRange
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            let queryParams = [
                "locationId": locationId,
                "startDate": dateFormatter.string(from: startDate),
                "endDate": dateFormatter.string(from: endDate)
            ]
            
            dashboardReport = try await apiClient.request(
                endpoint: .dashboardReport,
                queryParams: queryParams
            )
        } catch let networkError as NetworkError {
            error = networkError
        } catch {
            self.error = NetworkError.unknown(error)
        }
        
        isLoading = false
    }
}

// MARK: - Stock Alert ViewModel

@MainActor
class StockAlertViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    var outOfStockCount: Int {
        products.filter { ($0.totalInventory ?? 0) == 0 }.count
    }
    
    var lowStockCount: Int {
        products.filter { ($0.totalInventory ?? 0) > 0 && ($0.totalInventory ?? 0) < 10 }.count
    }
    
    var lowMarginCount: Int {
        products.filter { ($0.profitMargin ?? 100) < 10 }.count
    }
    
    var needsAttention: Bool {
        outOfStockCount > 0 || lowStockCount > 0 || lowMarginCount > 0
    }
    
    func loadProducts(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ProductListResponse = try await apiClient.request(
                endpoint: .listProducts,
                queryParams: ["locationId": locationId]
            )
            products = response.data
        } catch {
            // Silent fail — alerts are supplementary
            print("Failed to load products for stock alerts: \(error)")
        }
    }
}

// MARK: - Stock Alert Products View (linked from Dashboard)

struct StockAlertProductsView: View {
    let products: [Product]
    @State private var selectedFilter: AlertFilter = .outOfStock
    
    enum AlertFilter: String, CaseIterable {
        case outOfStock = "Out of Stock"
        case lowStock = "Low Stock"
        case lowMargin = "Low Margin"
    }
    
    private var filteredProducts: [Product] {
        switch selectedFilter {
        case .outOfStock:
            return products.filter { ($0.totalInventory ?? 0) == 0 }
        case .lowStock:
            return products.filter { ($0.totalInventory ?? 0) > 0 && ($0.totalInventory ?? 0) < 10 }
        case .lowMargin:
            return products.filter { ($0.profitMargin ?? 100) < 10 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(AlertFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                if filteredProducts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("No products in this category")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRow(product: product)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Inventory Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Actionable Signals Section (in DashboardView)

extension DashboardView {
    var actionableSignalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                
                Text("Action Required")
                    .font(.headline)
                
                Spacer()
                
                if signalsViewModel.signals.count > 3 {
                    NavigationLink {
                        AllSignalsView(signals: signalsViewModel.signals)
                    } label: {
                        Text("View All (\(signalsViewModel.signals.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
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
                    .foregroundColor(signal.severity.color)
                    .frame(width: 28, height: 28)
                    .background(signal.severity.color.opacity(0.12))
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.entityName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(signal.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        .foregroundColor(signal.severity.color)
                        .cornerRadius(4)
                    
                    if let cash = signal.formattedCashAtRisk {
                        Text(cash)
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                    
                    if signal.recommendedActions.count > 2 {
                        Text("+\(signal.recommendedActions.count - 2)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - All Signals View (full list)

struct AllSignalsView: View {
    let signals: [ActionableSignal]
    @State private var selectedType: SignalTypeFilter = .all
    
    enum SignalTypeFilter: String, CaseIterable {
        case all = "All"
        case atRisk = "At Risk"
        case slowMoving = "Slow Moving"
        case overstocked = "Overstocked"
    }
    
    private var filteredSignals: [ActionableSignal] {
        switch selectedType {
        case .all: return signals
        case .atRisk: return signals.filter { $0.type == .atRisk }
        case .slowMoving: return signals.filter { $0.type == .slowMovingExpensive }
        case .overstocked: return signals.filter { $0.type == .overstockedCategory }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $selectedType) {
                ForEach(SignalTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                if filteredSignals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("No signals in this category")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredSignals) { signal in
                        SignalDetailRow(signal: signal)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Action Signals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SignalDetailRow: View {
    let signal: ActionableSignal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: signal.type.icon)
                    .font(.subheadline)
                    .foregroundColor(signal.severity.color)
                    .frame(width: 32, height: 32)
                    .background(signal.severity.color.opacity(0.12))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.entityName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(signal.type.displayName)
                            .font(.caption)
                            .foregroundColor(signal.type.color)
                        
                        Text("\u{2022}")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(signal.severity.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(signal.severity.color)
                    }
                }
                
                Spacer()
                
                if let cash = signal.formattedCashAtRisk {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(cash)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("at risk")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Message
            Text(signal.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Recommended actions
            if !signal.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(signal.recommendedActions, id: \.self) { action in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(action)
                                .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Actionable Signals ViewModel

@MainActor
class ActionableSignalsViewModel: ObservableObject {
    @Published var signals: [ActionableSignal] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    func loadSignals(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ActionableSignalsResponse = try await apiClient.request(
                endpoint: .agingSignals,
                queryParams: [
                    "locationId": locationId,
                    "limit": "20"
                ]
            )
            signals = response.signals
        } catch {
            // Silent fail — signals are supplementary
            print("Failed to load actionable signals: \(error)")
            signals = []
        }
    }
}

// MARK: - Dashboard Expiring Products ViewModel

@MainActor
class DashboardExpiringViewModel: ObservableObject {
    @Published var products: [ExpiringProduct] = []
    @Published var summary: ExpiringProductsSummary?
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    var hasExpiringProducts: Bool {
        !products.isEmpty
    }
    
    func loadExpiring(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ExpiringProductsResponse = try await apiClient.request(
                endpoint: .agingExpiring,
                queryParams: [
                    "locationId": locationId,
                    "withinDays": "90",
                    "includeExpired": "true"
                ]
            )
            products = response.products
            summary = response.summary
        } catch {
            // Silent fail — expiry alerts are supplementary
            print("Failed to load expiring products: \(error)")
            products = []
            summary = nil
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AuthManager.shared)
}
