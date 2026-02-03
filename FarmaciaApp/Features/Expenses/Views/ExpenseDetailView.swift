import SwiftUI

// MARK: - Expense Detail View

struct ExpenseDetailView: View {
    let expense: Expense
    @ObservedObject var viewModel: ExpensesViewModel
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showMarkPaidConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Header Section
                Section {
                    VStack(spacing: 16) {
                        // Type Icon
                        ZStack {
                            Circle()
                                .fill(typeColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: expense.type.icon)
                                .font(.system(size: 36))
                                .foregroundColor(typeColor)
                        }
                        
                        // Amount
                        Text(expense.formattedAmount)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        // Type
                        Text(expense.type.displayName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // Status Badge
                        HStack(spacing: 8) {
                            if expense.isPaid {
                                Label("Paid", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundColor(.green)
                                    .cornerRadius(8)
                            } else {
                                Label("Unpaid", systemImage: "clock")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                
                // Details Section
                Section("Details") {
                    LabeledContent("Date") {
                        Text(expense.date, style: .date)
                    }
                    
                    if let description = expense.description, !description.isEmpty {
                        LabeledContent("Description") {
                            Text(description)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    if let vendor = expense.vendor, !vendor.isEmpty {
                        LabeledContent("Vendor") {
                            Text(vendor)
                        }
                    }
                    
                    if let reference = expense.reference, !reference.isEmpty {
                        LabeledContent("Reference") {
                            Text(reference)
                        }
                    }
                }
                
                // Payment Section
                Section("Payment") {
                    LabeledContent("Status") {
                        Text(expense.isPaid ? "Paid" : "Unpaid")
                            .foregroundColor(expense.isPaid ? .green : .orange)
                    }
                    
                    if expense.isPaid, let paidAt = expense.paidAt {
                        LabeledContent("Paid On") {
                            Text(paidAt, style: .date)
                        }
                    }
                }
                
                // Notes Section
                if let notes = expense.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }
                
                // Metadata Section
                Section("Info") {
                    LabeledContent("Created") {
                        Text(expense.createdAt, style: .date)
                    }
                    
                    if let location = expense.location {
                        LabeledContent("Location") {
                            Text(location.name)
                        }
                    }
                }
                
                // Actions Section
                Section {
                    if !expense.isPaid {
                        Button {
                            showMarkPaidConfirmation = true
                        } label: {
                            Label("Mark as Paid", systemImage: "checkmark.circle")
                        }
                        .foregroundColor(.green)
                    }
                    
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Expense", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Expense", systemImage: "trash")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                ExpenseFormView(viewModel: viewModel, expense: expense)
            }
            .alert("Delete Expense", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteExpense() }
                }
            } message: {
                Text("Are you sure you want to delete this expense? This action cannot be undone.")
            }
            .alert("Mark as Paid", isPresented: $showMarkPaidConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Mark Paid") {
                    Task { await markAsPaid() }
                }
            } message: {
                Text("Mark this expense as paid?")
            }
        }
    }
    
    // MARK: - Type Color
    
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
    
    // MARK: - Actions
    
    private func deleteExpense() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        
        let success = await viewModel.deleteExpense(id: expense.id, locationId: locationId)
        if success {
            dismiss()
        }
    }
    
    private func markAsPaid() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        
        let success = await viewModel.markAsPaid(id: expense.id, locationId: locationId)
        if success {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    let expense = Expense(
        id: "1",
        locationId: "loc1",
        type: .rent,
        amount: "1500.00",
        date: Date(),
        description: "Monthly rent",
        vendor: "ABC Properties",
        reference: "INV-001",
        isPaid: false,
        paidAt: nil,
        notes: "Due on the 1st of each month",
        createdBy: nil,
        createdAt: Date(),
        location: nil
    )
    
    return ExpenseDetailView(expense: expense, viewModel: ExpensesViewModel())
        .environmentObject(AuthManager.shared)
}
