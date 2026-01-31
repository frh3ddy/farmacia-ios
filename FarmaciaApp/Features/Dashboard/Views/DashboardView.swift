import SwiftUI

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    welcomeHeader
                    
                    // Quick Stats
                    if let report = viewModel.dashboardReport {
                        quickStatsSection(report: report)
                        
                        // Sales Summary
                        salesSummarySection(report: report)
                        
                        // Inventory Overview
                        inventorySummarySection(report: report)
                        
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
            .task {
                await viewModel.loadDashboard()
            }
        }
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
    
    // MARK: - Quick Stats Section
    
    private func quickStatsSection(report: DashboardReport) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Today's Sales",
                value: report.sales.totalRevenue,
                icon: "dollarsign.circle.fill",
                color: .green
            )
            
            StatCard(
                title: "Gross Profit",
                value: report.sales.grossProfit,
                icon: "chart.line.uptrend.xyaxis",
                color: .blue
            )
            
            StatCard(
                title: "Inventory Value",
                value: report.inventory.totalValue,
                icon: "shippingbox.fill",
                color: .orange
            )
            
            StatCard(
                title: "Net Profit",
                value: report.netProfit.amount,
                icon: "banknote.fill",
                color: (Double(report.netProfit.marginPercent) ?? 0) >= 0 ? .green : .red
            )
        }
    }
    
    // MARK: - Sales Summary Section
    
    private func salesSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Sales Summary", icon: "cart.fill")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Revenue", value: report.sales.totalRevenue)
                summaryRow(label: "Cost of Goods Sold", value: report.sales.totalCOGS)
                summaryRow(label: "Gross Profit", value: report.sales.grossProfit)
                summaryRow(label: "Gross Margin", value: "\(report.sales.grossMarginPercent)%")
                
                Divider()
                
                HStack {
                    Text("Units Sold")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(report.sales.totalUnitsSold)")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
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
                summaryRow(label: "Total Value", value: report.inventory.totalValue)
                summaryRow(label: "Products", value: "\(report.inventory.totalProducts)")
                summaryRow(label: "Avg Cost/Unit", value: report.inventory.averageCostPerUnit)
                
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
    
    // MARK: - Adjustments Summary Section
    
    private func adjustmentsSummarySection(report: DashboardReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Adjustments", icon: "arrow.up.arrow.down")
            
            VStack(spacing: 8) {
                summaryRow(label: "Total Adjustments", value: "\(report.adjustments.totalAdjustments)")
                summaryRow(label: "Total Loss", value: report.adjustments.totalLoss, valueColor: .red)
                summaryRow(label: "Total Gain", value: report.adjustments.totalGain, valueColor: .green)
                summaryRow(label: "Net Impact", value: report.adjustments.netImpact)
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
                summaryRow(label: "Revenue", value: report.sales.totalRevenue, valueColor: .green)
                summaryRow(label: "COGS", value: "(\(report.sales.totalCOGS))")
                summaryRow(label: "Operating Expenses", value: "(\(report.operatingExpenses.total))")
                
                Divider()
                
                HStack {
                    Text("Net Profit")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(report.netProfit.amount)
                        .fontWeight(.bold)
                        .foregroundColor((Double(report.netProfit.marginPercent) ?? 0) >= 0 ? .green : .red)
                }
                
                HStack {
                    Text("Net Margin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(report.netProfit.marginPercent)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
            HStack(spacing: 4) {
                Image(systemName: "building.2")
                Text(authManager.currentLocation?.name ?? "Location")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
        }
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
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboardReport: DashboardReport?
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showLocationSwitcher = false
    
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
            
            // Calculate date range (last 30 days)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            
            let dateFormatter = ISO8601DateFormatter()
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

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AuthManager.shared)
}

