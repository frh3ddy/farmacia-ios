import SwiftUI

// MARK: - Expenses View

struct ExpensesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = ExpensesViewModel()
    @State private var showAddExpense = false
    @State private var selectedExpense: Expense?
    @State private var showFilterSheet = false
    @State private var filterType: ExpenseType?
    @State private var filterPaidStatus: PaidFilter = .all
    
    enum PaidFilter: String, CaseIterable {
        case all = "All"
        case paid = "Paid"
        case unpaid = "Unpaid"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary Card
                if let summary = viewModel.summary {
                    ExpenseSummaryCard(summary: summary)
                        .padding()
                }
                
                // Filter Bar
                filterBar
                
                Divider()
                
                // Expense List
                if viewModel.isLoading {
                    ProgressView("Loading expenses...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredExpenses.isEmpty {
                    emptyStateView
                } else {
                    expenseList
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                ExpenseFormView(viewModel: viewModel, expense: nil)
            }
            .sheet(item: $selectedExpense) { expense in
                ExpenseDetailView(expense: expense, viewModel: viewModel)
            }
            .onAppear {
                loadData()
            }
            .refreshable {
                await refreshData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {}
            } message: {
                Text(viewModel.successMessage ?? "Operation completed")
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Paid Status Filter
                Menu {
                    ForEach(PaidFilter.allCases, id: \.self) { filter in
                        Button {
                            filterPaidStatus = filter
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                if filterPaidStatus == filter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        title: filterPaidStatus.rawValue,
                        isActive: filterPaidStatus != .all
                    )
                }
                
                // Type Filter
                Menu {
                    Button {
                        filterType = nil
                    } label: {
                        HStack {
                            Text("All Types")
                            if filterType == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(ExpenseType.allCases, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                                if filterType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        title: filterType?.displayName ?? "All Types",
                        isActive: filterType != nil
                    )
                }
                
                // Clear filters
                if filterType != nil || filterPaidStatus != .all {
                    Button {
                        filterType = nil
                        filterPaidStatus = .all
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Filtered Expenses
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        if let type = filterType {
            expenses = expenses.filter { $0.type == type }
        }
        
        switch filterPaidStatus {
        case .paid:
            expenses = expenses.filter { $0.isPaid }
        case .unpaid:
            expenses = expenses.filter { !$0.isPaid }
        case .all:
            break
        }
        
        return expenses
    }
    
    // MARK: - Expense List
    
    private var expenseList: some View {
        List {
            ForEach(filteredExpenses) { expense in
                ExpenseRow(expense: expense)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExpense = expense
                    }
            }
            .onDelete { indexSet in
                deleteExpenses(at: indexSet)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Expenses")
                .font(.headline)
            
            Text("Tap + to add your first expense")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadData() {
        Task {
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadExpenses(locationId: locationId)
                await viewModel.loadSummary(locationId: locationId)
            }
        }
    }
    
    private func refreshData() async {
        if let locationId = authManager.currentLocation?.id {
            await viewModel.loadExpenses(locationId: locationId)
            await viewModel.loadSummary(locationId: locationId)
        }
    }
    
    private func deleteExpenses(at indexSet: IndexSet) {
        guard let locationId = authManager.currentLocation?.id else { return }
        
        for index in indexSet {
            let expense = filteredExpenses[index]
            Task {
                await viewModel.deleteExpense(id: expense.id, locationId: locationId)
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
            Image(systemName: "chevron.down")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.blue.opacity(0.15) : Color(.systemGray6))
        .foregroundColor(isActive ? .blue : .primary)
        .cornerRadius(16)
    }
}

// MARK: - Expense Summary Card

struct ExpenseSummaryCard: View {
    let summary: ExpenseSummary
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(summary.totalDouble))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(summary.expenseCount) expenses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(summary.paidDouble))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Unpaid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(summary.unpaidDouble))
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: expense.type.icon)
                    .foregroundColor(typeColor)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.type.displayName)
                        .font(.headline)
                    
                    if !expense.isPaid {
                        Text("Unpaid")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                
                if let description = expense.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(expense.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(expense.formattedAmount)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
    
    private var typeColor: Color {
        switch expense.type.color {
        case "blue": return .blue
        case "yellow": return .yellow
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "gray": return .gray
        case "red": return .red
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "mint": return .mint
        default: return .secondary
        }
    }
}

// MARK: - Expenses ViewModel

@MainActor
class ExpensesViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var summary: ExpenseSummary?
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var successMessage: String?
    @Published var showSuccess = false
    
    private let apiClient = APIClient.shared
    
    // MARK: - Load Expenses
    
    func loadExpenses(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ExpenseListResponse = try await apiClient.request(
                endpoint: .listExpenses,
                queryParams: ["locationId": locationId]
            )
            expenses = response.data.sorted { $0.date > $1.date }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Failed to load expenses"
            showError = true
        }
    }
    
    // MARK: - Load Summary
    
    func loadSummary(locationId: String) async {
        do {
            let response: ExpenseSummaryResponse = try await apiClient.request(
                endpoint: .expenseSummary,
                queryParams: ["locationId": locationId]
            )
            summary = response.data
        } catch {
            // Summary is optional, don't show error
            print("Failed to load expense summary: \(error)")
        }
    }
    
    // MARK: - Create Expense
    
    func createExpense(
        locationId: String,
        type: ExpenseType,
        amount: Double,
        date: Date,
        description: String?,
        vendor: String?,
        reference: String?,
        isPaid: Bool,
        paidAt: Date?,
        notes: String?
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        
        let request = CreateExpenseRequest(
            locationId: locationId,
            type: type.rawValue,
            amount: amount,
            date: date,
            description: description,
            vendor: vendor,
            reference: reference,
            isPaid: isPaid,
            paidAt: isPaid ? (paidAt ?? date) : nil,
            notes: notes,
            createdBy: nil
        )
        
        do {
            let response: ExpenseCreateResponse = try await apiClient.request(
                endpoint: .createExpense,
                body: request
            )
            successMessage = response.message
            showSuccess = true
            await loadExpenses(locationId: locationId)
            await loadSummary(locationId: locationId)
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Failed to create expense"
            showError = true
            return false
        }
    }
    
    // MARK: - Update Expense
    
    func updateExpense(
        id: String,
        locationId: String,
        type: ExpenseType?,
        amount: Double?,
        date: Date?,
        description: String?,
        vendor: String?,
        reference: String?,
        isPaid: Bool?,
        paidAt: Date?,
        notes: String?
    ) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        
        let request = UpdateExpenseRequest(
            type: type?.rawValue,
            amount: amount,
            date: date,
            description: description,
            vendor: vendor,
            reference: reference,
            isPaid: isPaid,
            paidAt: paidAt,
            notes: notes
        )
        
        do {
            let _: ExpenseCreateResponse = try await apiClient.request(
                endpoint: .updateExpense(id: id),
                body: request
            )
            successMessage = "Expense updated"
            showSuccess = true
            await loadExpenses(locationId: locationId)
            await loadSummary(locationId: locationId)
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Failed to update expense"
            showError = true
            return false
        }
    }
    
    // MARK: - Delete Expense
    
    func deleteExpense(id: String, locationId: String) async -> Bool {
        do {
            let _: ExpenseActionResponse = try await apiClient.request(
                endpoint: .deleteExpense(id: id)
            )
            successMessage = "Expense deleted"
            showSuccess = true
            await loadExpenses(locationId: locationId)
            await loadSummary(locationId: locationId)
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Failed to delete expense"
            showError = true
            return false
        }
    }
    
    // MARK: - Mark as Paid
    
    func markAsPaid(id: String, locationId: String) async -> Bool {
        return await updateExpense(
            id: id,
            locationId: locationId,
            type: nil,
            amount: nil,
            date: nil,
            description: nil,
            vendor: nil,
            reference: nil,
            isPaid: true,
            paidAt: Date(),
            notes: nil
        )
    }
}

// MARK: - Expense Action Response

struct ExpenseActionResponse: Decodable {
    let success: Bool
    let message: String
}

// MARK: - Preview

#Preview {
    ExpensesView()
        .environmentObject(AuthManager.shared)
}
