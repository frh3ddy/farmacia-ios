import SwiftUI

// MARK: - Expense Form View

struct ExpenseFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: ExpensesViewModel
    
    let expense: Expense?
    
    @State private var selectedType: ExpenseType = .other
    @State private var amount = ""
    @State private var date = Date()
    @State private var description = ""
    @State private var vendor = ""
    @State private var reference = ""
    @State private var isPaid = false
    @State private var paidAt = Date()
    @State private var notes = ""
    
    private var isEditing: Bool {
        expense != nil
    }
    
    private var isValid: Bool {
        !amount.isEmpty && Double(amount) ?? 0 > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Type Selection
                Section("Expense Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ExpenseType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Amount & Date
                Section("Amount & Date") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                // Description & Vendor
                Section("Details") {
                    TextField("Description", text: $description)
                    TextField("Vendor/Payee", text: $vendor)
                    TextField("Reference/Invoice #", text: $reference)
                }
                
                // Payment Status
                Section("Payment Status") {
                    Toggle("Paid", isOn: $isPaid)
                    
                    if isPaid {
                        DatePicker("Paid Date", selection: $paidAt, displayedComponents: .date)
                    }
                }
                
                // Notes
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                // Quick Amount Buttons
                Section("Quick Amounts") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([50, 100, 250, 500, 1000, 2500], id: \.self) { value in
                                Button("$\(value)") {
                                    amount = String(value)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!isValid || viewModel.isSubmitting)
                }
            }
            .onAppear {
                if let expense = expense {
                    populateForm(from: expense)
                }
            }
        }
    }
    
    // MARK: - Populate Form
    
    private func populateForm(from expense: Expense) {
        selectedType = expense.type
        amount = String(expense.amountDouble)
        date = expense.date
        description = expense.description ?? ""
        vendor = expense.vendor ?? ""
        reference = expense.reference ?? ""
        isPaid = expense.isPaid
        paidAt = expense.paidAt ?? Date()
        notes = expense.notes ?? ""
    }
    
    // MARK: - Save
    
    private func save() async {
        guard let amountValue = Double(amount),
              let locationId = authManager.currentLocation?.id else { return }
        
        let success: Bool
        
        if let expense = expense {
            // Update existing
            success = await viewModel.updateExpense(
                id: expense.id,
                locationId: locationId,
                type: selectedType,
                amount: amountValue,
                date: date,
                description: description.isEmpty ? nil : description,
                vendor: vendor.isEmpty ? nil : vendor,
                reference: reference.isEmpty ? nil : reference,
                isPaid: isPaid,
                paidAt: isPaid ? paidAt : nil,
                notes: notes.isEmpty ? nil : notes
            )
        } else {
            // Create new
            success = await viewModel.createExpense(
                locationId: locationId,
                type: selectedType,
                amount: amountValue,
                date: date,
                description: description.isEmpty ? nil : description,
                vendor: vendor.isEmpty ? nil : vendor,
                reference: reference.isEmpty ? nil : reference,
                isPaid: isPaid,
                paidAt: isPaid ? paidAt : nil,
                notes: notes.isEmpty ? nil : notes
            )
        }
        
        if success {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ExpenseFormView(viewModel: ExpensesViewModel(), expense: nil)
        .environmentObject(AuthManager.shared)
}
