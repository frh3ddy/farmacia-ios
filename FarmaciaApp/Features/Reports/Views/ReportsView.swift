import SwiftUI

// MARK: - Reports View

struct ReportsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            List {
                // Sales & Profit Reports
                Section("Sales & Profit") {
                    NavigationLink {
                        COGSReportView()
                    } label: {
                        reportRow(
                            title: "Cost of Goods Sold",
                            subtitle: "Track product costs and sales",
                            icon: "dollarsign.square",
                            color: .green
                        )
                    }
                    
                    NavigationLink {
                        ProfitMarginReportView()
                    } label: {
                        reportRow(
                            title: "Profit Margin",
                            subtitle: "Revenue vs. cost analysis",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue
                        )
                    }
                    
                    NavigationLink {
                        ProfitLossReportView()
                    } label: {
                        reportRow(
                            title: "Profit & Loss",
                            subtitle: "Full P&L statement",
                            icon: "chart.bar.doc.horizontal",
                            color: .purple
                        )
                    }
                }
                
                // Inventory Reports
                Section("Inventory") {
                    NavigationLink {
                        ValuationReportView()
                    } label: {
                        reportRow(
                            title: "Inventory Valuation",
                            subtitle: "Current stock value",
                            icon: "shippingbox",
                            color: .orange
                        )
                    }
                    
                    NavigationLink {
                        ReceivingSummaryReportView()
                    } label: {
                        reportRow(
                            title: "Receiving Summary",
                            subtitle: "Inventory received",
                            icon: "arrow.down.circle",
                            color: .teal
                        )
                    }
                    
                    NavigationLink {
                        AdjustmentImpactReportView()
                    } label: {
                        reportRow(
                            title: "Adjustment Impact",
                            subtitle: "Shrinkage and gains",
                            icon: "exclamationmark.triangle",
                            color: .red
                        )
                    }
                }
                
                // Expenses
                if authManager.canManageExpenses {
                    Section("Expenses") {
                        NavigationLink {
                            ExpenseSummaryReportView()
                        } label: {
                            reportRow(
                                title: "Expense Summary",
                                subtitle: "Operating expenses breakdown",
                                icon: "creditcard",
                                color: .indigo
                            )
                        }
                    }
                }
            }
            .navigationTitle("Reports")
        }
    }
    
    private func reportRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reports ViewModel

@MainActor
class ReportsViewModel: ObservableObject {
    @Published var cogsReport: COGSReport?
    @Published var valuationReport: ValuationReport?
    @Published var profitMarginReport: ProfitMarginReport?
    @Published var profitLossReport: ProfitLossReport?
    @Published var adjustmentImpactReport: AdjustmentImpactReport?
    @Published var receivingSummaryReport: ReceivingSummaryReport?
    @Published var expenseSummary: ExpenseSummary?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let apiClient = APIClient.shared
    
    // Date range
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var endDate: Date = Date()
    
    private var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }
    
    // MARK: - COGS Report
    
    func loadCOGSReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ReportResponse<COGSReport> = try await apiClient.request(
                endpoint: .cogsReport,
                queryParams: params
            )
            cogsReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load COGS report"
            showError = true
        }
    }
    
    // MARK: - Valuation Report
    
    func loadValuationReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [:]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ReportResponse<ValuationReport> = try await apiClient.request(
                endpoint: .valuationReport,
                queryParams: params.isEmpty ? nil : params
            )
            valuationReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load valuation report"
            showError = true
        }
    }
    
    // MARK: - Profit Margin Report
    
    func loadProfitMarginReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ReportResponse<ProfitMarginReport> = try await apiClient.request(
                endpoint: .profitMarginReport,
                queryParams: params
            )
            profitMarginReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load profit margin report"
            showError = true
        }
    }
    
    // MARK: - Profit & Loss Report
    
    func loadProfitLossReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ReportResponse<ProfitLossReport> = try await apiClient.request(
                endpoint: .profitLossReport,
                queryParams: params
            )
            profitLossReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load P&L report"
            showError = true
        }
    }
    
    // MARK: - Adjustment Impact Report
    
    func loadAdjustmentImpactReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ReportResponse<AdjustmentImpactReport> = try await apiClient.request(
                endpoint: .adjustmentImpactReport,
                queryParams: params
            )
            adjustmentImpactReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load adjustment impact report"
            showError = true
        }
    }
    
    // MARK: - Receiving Summary Report
    
    func loadReceivingSummaryReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ReportResponse<ReceivingSummaryReport> = try await apiClient.request(
                endpoint: .receivingSummaryReport,
                queryParams: params
            )
            receivingSummaryReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load receiving summary report"
            showError = true
        }
    }
    
    // MARK: - Expense Summary
    
    func loadExpenseSummary(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }
        
        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
            "includeMonthly": "true"
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }
        
        do {
            let response: ExpenseSummaryResponse = try await apiClient.request(
                endpoint: .expenseSummary,
                queryParams: params
            )
            expenseSummary = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load expense summary"
            showError = true
        }
    }
}

// MARK: - Report Response

struct ReportResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
}

// MARK: - Date Range Picker

struct DateRangePicker: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            
            Button("Apply") {
                onApply()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Report Header Card

struct ReportHeaderCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    
    init(title: String, value: String, subtitle: String? = nil, color: Color = .blue) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Currency Formatter

func formatCurrency(_ value: String) -> String {
    guard let doubleValue = Double(value) else { return "$\(value)" }
    return formatCurrency(doubleValue)
}

func formatCurrency(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "USD"
    return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
}

func formatPercent(_ value: String) -> String {
    guard let doubleValue = Double(value) else { return "\(value)%" }
    return String(format: "%.1f%%", doubleValue)
}

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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.cogsReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Total COGS",
                            value: formatCurrency(report.summary.totalCOGS),
                            color: .red
                        )
                        
                        ReportHeaderCard(
                            title: "Revenue",
                            value: formatCurrency(report.summary.totalRevenue),
                            color: .green
                        )
                        
                        ReportHeaderCard(
                            title: "Gross Profit",
                            value: formatCurrency(report.summary.grossProfit),
                            color: .blue
                        )
                        
                        ReportHeaderCard(
                            title: "Margin",
                            value: formatPercent(report.summary.grossMarginPercent),
                            color: .purple
                        )
                        
                        ReportHeaderCard(
                            title: "Units Sold",
                            value: "\(report.summary.totalUnitsSold)",
                            color: .orange
                        )
                        
                        ReportHeaderCard(
                            title: "Total Sales",
                            value: "\(report.summary.totalSales)",
                            color: .teal
                        )
                    }
                    .padding(.horizontal)
                    
                    // By Product
                    if !report.byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Product")
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
                            Text("By Category")
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
        .navigationTitle("Cost of Goods Sold")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No data available")
                .foregroundColor(.secondary)
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
                
                Text("\(product.unitsSold) units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(product.totalCost))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatPercent(product.marginPercent))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
                
                Text("Profit: \(formatCurrency(category.grossProfit))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(category.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Valuation Report View

struct ValuationReportView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ReportsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.valuationReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Total Value",
                            value: formatCurrency(report.summary.totalValue),
                            color: .green
                        )
                        
                        ReportHeaderCard(
                            title: "Total Units",
                            value: "\(report.summary.totalUnits)",
                            color: .blue
                        )
                        
                        ReportHeaderCard(
                            title: "Products",
                            value: "\(report.summary.totalProducts)",
                            color: .purple
                        )
                        
                        ReportHeaderCard(
                            title: "Avg Cost/Unit",
                            value: formatCurrency(report.summary.averageCostPerUnit),
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Aging Summary
                    if let aging = report.agingSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Aging Summary")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            AgingSummaryView(aging: aging)
                        }
                        .padding(.top)
                    }
                    
                    // By Product
                    if !report.byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Product")
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
        .navigationTitle("Inventory Valuation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .refreshable { await refreshReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No inventory data")
                .foregroundColor(.secondary)
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
            AgingRow(label: "< 30 days", units: aging.under30Days.units, value: aging.under30Days.value, color: .green)
            AgingRow(label: "30-60 days", units: aging.days30to60.units, value: aging.days30to60.value, color: .yellow)
            AgingRow(label: "60-90 days", units: aging.days60to90.units, value: aging.days60to90.value, color: .orange)
            AgingRow(label: "> 90 days", units: aging.over90Days.units, value: aging.over90Days.value, color: .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
            
            Text("\(units) units")
                .font(.caption)
                .foregroundColor(.secondary)
            
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
                
                Text("\(product.totalQuantity) units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(product.totalValue))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("@\(formatCurrency(product.averageCost))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Profit Margin Report View

struct ProfitMarginReportView: View {
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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.profitMarginReport {
                    // Summary Card
                    ReportHeaderCard(
                        title: "Overall Margin",
                        value: formatPercent(report.overallMargin),
                        color: .purple
                    )
                    .padding(.horizontal)
                    
                    // By Product
                    if !report.byProduct.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Product")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(report.byProduct, id: \.productId) { product in
                                ProductMarginRow(product: product)
                            }
                        }
                        .padding(.top)
                    }
                    
                    // Trends
                    if let trends = report.trends, !trends.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trends")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(trends, id: \.date) { trend in
                                TrendRow(trend: trend)
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
        .navigationTitle("Profit Margin")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No margin data")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func loadReport() {
        Task {
            await viewModel.loadProfitMarginReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct ProductMarginRow: View {
    let product: ProductProfitMargin
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(product.unitsSold) units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(product.profit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(formatPercent(product.marginPercent))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct TrendRow: View {
    let trend: MarginTrend
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Revenue: \(formatCurrency(trend.revenue))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(trend.profit))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Double(trend.profit) ?? 0 >= 0 ? .green : .red)
                
                Text(formatPercent(trend.marginPercent))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.profitLossReport {
                    VStack(spacing: 0) {
                        // Revenue Section
                        PLSection(title: "Revenue", color: .green) {
                            PLRow(label: "Total Sales", value: report.revenue.sales, isTotal: false)
                            PLRow(label: "Total Revenue", value: report.revenue.total, isTotal: true)
                        }
                        
                        // COGS Section
                        PLSection(title: "Cost of Goods Sold", color: .red) {
                            PLRow(label: "Product Costs", value: report.costOfGoodsSold.productCosts, isTotal: false, isNegative: true)
                            PLRow(label: "Total COGS", value: report.costOfGoodsSold.total, isTotal: true, isNegative: true)
                        }
                        
                        // Gross Profit
                        PLSummaryRow(
                            label: "Gross Profit",
                            value: report.grossProfit.amount,
                            subtitle: "\(formatPercent(report.grossProfit.marginPercent)) margin",
                            color: .blue
                        )
                        
                        // Operating Expenses
                        PLSection(title: "Operating Expenses", color: .orange) {
                            ForEach(report.operatingExpenses.byType, id: \.type) { expense in
                                PLRow(label: expense.type, value: expense.amount, isTotal: false, isNegative: true)
                            }
                            PLRow(label: "Shrinkage", value: report.operatingExpenses.shrinkage, isTotal: false, isNegative: true)
                            PLRow(label: "Total Expenses", value: report.operatingExpenses.total, isTotal: true, isNegative: true)
                        }
                        
                        // Net Profit
                        PLSummaryRow(
                            label: "Net Profit",
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
        .navigationTitle("Profit & Loss")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No P&L data")
                .foregroundColor(.secondary)
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
                .foregroundColor(color)
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
                .foregroundColor(isNegative ? .red : .primary)
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
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(value))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
        .padding(.vertical, 8)
    }
}

// MARK: - Adjustment Impact Report View

struct AdjustmentImpactReportView: View {
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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.adjustmentImpactReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Total Loss",
                            value: formatCurrency(report.summary.totalLoss),
                            color: .red
                        )
                        
                        ReportHeaderCard(
                            title: "Total Gain",
                            value: formatCurrency(report.summary.totalGain),
                            color: .green
                        )
                        
                        ReportHeaderCard(
                            title: "Net Impact",
                            value: formatCurrency(report.summary.netImpact),
                            color: Double(report.summary.netImpact) ?? 0 >= 0 ? .green : .red
                        )
                        
                        ReportHeaderCard(
                            title: "Adjustments",
                            value: "\(report.summary.totalAdjustments)",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // By Type
                    if !report.byType.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Type")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(report.byType) { typeImpact in
                                AdjustmentTypeRow(impact: typeImpact)
                            }
                        }
                        .padding(.top)
                    }
                    
                    // By Product
                    if let products = report.byProduct, !products.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Product")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(products) { product in
                                ProductAdjustmentRow(product: product)
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
        .navigationTitle("Adjustment Impact")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No adjustment data")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func loadReport() {
        Task {
            await viewModel.loadAdjustmentImpactReport(locationId: authManager.currentLocation?.id)
        }
    }
}

struct AdjustmentTypeRow: View {
    let impact: AdjustmentTypeImpact
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(impact.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(impact.count) adjustments • \(impact.totalQuantity) units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(impact.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct ProductAdjustmentRow: View {
    let product: ProductAdjustmentImpact
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(product.adjustmentCount) adjustments • \(product.totalQuantity) units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if Double(product.totalLoss) ?? 0 > 0 {
                    Text("-\(formatCurrency(product.totalLoss))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if Double(product.totalGain) ?? 0 > 0 {
                    Text("+\(formatCurrency(product.totalGain))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Text(formatCurrency(product.netImpact))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Double(product.netImpact) ?? 0 >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = viewModel.receivingSummaryReport {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Total Cost",
                            value: formatCurrency(report.summary.totalCost),
                            color: .green
                        )
                        
                        ReportHeaderCard(
                            title: "Total Qty",
                            value: "\(report.summary.totalQuantity)",
                            color: .blue
                        )
                        
                        ReportHeaderCard(
                            title: "Receivings",
                            value: "\(report.summary.totalReceivings)",
                            color: .purple
                        )
                        
                        ReportHeaderCard(
                            title: "Avg Cost",
                            value: formatCurrency(report.summary.averageCostPerUnit),
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // By Supplier
                    if let suppliers = report.bySupplier, !suppliers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("By Supplier")
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
                            Text("By Product")
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
        .navigationTitle("Receiving Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No receiving data")
                .foregroundColor(.secondary)
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
                
                Text("\(supplier.receivingCount) receivings • \(supplier.totalQuantity) units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(supplier.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
                
                Text("\(product.receivingCount) receivings • \(product.totalQuantity) units @ \(formatCurrency(product.averageCost))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(product.totalCost))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

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
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let summary = viewModel.expenseSummary {
                    // Summary Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ReportHeaderCard(
                            title: "Total Expenses",
                            value: formatCurrency(summary.totalExpenses),
                            color: .red
                        )
                        
                        ReportHeaderCard(
                            title: "Expense Count",
                            value: "\(summary.expenseCount)",
                            color: .blue
                        )
                        
                        ReportHeaderCard(
                            title: "Paid",
                            value: formatCurrency(summary.paidExpenses),
                            color: .green
                        )
                        
                        ReportHeaderCard(
                            title: "Unpaid",
                            value: formatCurrency(summary.unpaidExpenses),
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    // By Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text("By Type")
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
                            Text("By Month")
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
        .navigationTitle("Expense Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadReport() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No expense data")
                .foregroundColor(.secondary)
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
                
                Text("\(typeSummary.count) expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(typeSummary.total))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatPercent(typeSummary.percentage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
                
                Text("\(month.count) expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatCurrency(month.total))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    ReportsView()
        .environmentObject(AuthManager.shared)
}
