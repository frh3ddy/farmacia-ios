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

// MARK: - Report Placeholder Views

struct COGSReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Cost of Goods Sold", icon: "dollarsign.square")
    }
}

struct ProfitMarginReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Profit Margin", icon: "chart.line.uptrend.xyaxis")
    }
}

struct ProfitLossReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Profit & Loss", icon: "chart.bar.doc.horizontal")
    }
}

struct ValuationReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Inventory Valuation", icon: "shippingbox")
    }
}

struct ReceivingSummaryReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Receiving Summary", icon: "arrow.down.circle")
    }
}

struct AdjustmentImpactReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Adjustment Impact", icon: "exclamationmark.triangle")
    }
}

struct ExpenseSummaryReportView: View {
    var body: some View {
        ReportPlaceholderView(title: "Expense Summary", icon: "creditcard")
    }
}

// MARK: - Report Placeholder View

struct ReportPlaceholderView: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Report data will appear here")
                .foregroundColor(.secondary)
            
            Text("Connect to the API to load report data")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ReportsView()
        .environmentObject(AuthManager.shared)
}
