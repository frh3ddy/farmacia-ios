import SwiftUI

// MARK: - Expense Form View

struct ExpenseFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: ExpensesViewModel
    @StateObject private var payrollViewModel = PayrollViewModel()
    
    let expense: Expense?
    
    @State private var selectedType: ExpenseType = .other
    @State private var amount: Double?
    @State private var date = Date()
    @State private var description = ""
    @State private var vendor = ""
    @State private var reference = ""
    @State private var isPaid = false
    @State private var paidAt = Date()
    @State private var notes = ""
    
    // Payroll (nómina) autofill state
    @State private var selectedTeamMember: TeamMember?
    @State private var payrollUseCustomRange = false
    @State private var payrollStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var payrollEnd = Date()
    @State private var payrollAutofilled = false
    
    private var isEditing: Bool {
        expense != nil
    }
    
    private var isPayrollType: Bool {
        selectedType == .payroll
    }
    
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
    
    private var isValid: Bool {
        (amount ?? 0) > 0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Type Selection
                Section("Tipo de Gasto") {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(ExpenseType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Payroll: employee picker + period
                if isPayrollType && !isEditing {
                    payrollSection
                }
                
                // Amount & Date
                Section("Monto y Fecha") {
                    HStack {
                        Text("Monto")
                        Spacer()
                        Text("$")
                        TextField("0.00", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                }
                
                // Description & Vendor
                Section("Detalles") {
                    TextField("Descripción", text: $description)
                    TextField("Proveedor/Beneficiario", text: $vendor)
                    TextField("Referencia/Factura #", text: $reference)
                }
                
                // Payment Status
                Section("Estado de Pago") {
                    Toggle("Pagado", isOn: $isPaid)
                    
                    if isPaid {
                        DatePicker("Fecha de Pago", selection: $paidAt, displayedComponents: .date)
                    }
                }
                
                // Notes
                Section("Notas (Opcional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
                
                // Quick Amount Buttons
                Section("Montos Rápidos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([50, 100, 250, 500, 1000, 2500], id: \.self) { value in
                                Button("$\(value)") {
                                    amount = Double(value)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Gasto" : "Agregar Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
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
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "Ocurrió un error")
            }
            .alert("Error", isPresented: $payrollViewModel.showError) {
                Button("OK") {}
            } message: {
                Text(payrollViewModel.errorMessage ?? "Ocurrió un error")
            }
        }
    }
    
    // MARK: - Payroll Section
    
    private var payrollSection: some View {
        Section("Nómina (desde Square)") {
            if payrollViewModel.isLoadingMembers {
                HStack {
                    ProgressView()
                    Text("Cargando empleados...")
                        .foregroundStyle(.secondary)
                }
            } else if payrollViewModel.teamMembers.isEmpty {
                Button("Cargar empleados de Square") {
                    Task { await payrollViewModel.loadTeamMembers() }
                }
            } else {
                Picker("Empleado", selection: $selectedTeamMember) {
                    Text("Seleccionar...").tag(TeamMember?.none)
                    ForEach(payrollViewModel.teamMembers) { member in
                        Text(member.displayName).tag(TeamMember?.some(member))
                    }
                }
                
                if selectedTeamMember != nil {
                    Toggle("Rango personalizado", isOn: $payrollUseCustomRange)
                    
                    if payrollUseCustomRange {
                        DatePicker("Desde", selection: $payrollStart, displayedComponents: .date)
                        DatePicker("Hasta", selection: $payrollEnd, displayedComponents: .date)
                    } else {
                        HStack {
                            Text("Periodo")
                            Spacer()
                            Text("Semana actual (Lun - Dom)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        Task { await autofillFromPayroll() }
                    } label: {
                        HStack {
                            if payrollViewModel.isLoadingSummary {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.down.doc")
                            }
                            Text("Calcular y autocompletar")
                        }
                    }
                    .disabled(payrollViewModel.isLoadingSummary)
                    
                    if payrollAutofilled, let summary = payrollViewModel.summary {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("\(summary.workedDays) días trabajados", systemImage: "calendar")
                            Label("\(summary.formattedTotalTime) horas", systemImage: "clock")
                            Label("$\(String(format: "%.2f", summary.hourlyRate))/hora", systemImage: "dollarsign.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if isPayrollType && payrollViewModel.teamMembers.isEmpty {
                Task { await payrollViewModel.loadTeamMembers() }
            }
        }
    }
    
    // MARK: - Payroll Autofill
    
    private func autofillFromPayroll() async {
        guard let member = selectedTeamMember else { return }
        
        payrollViewModel.selectedMember = member
        payrollViewModel.useCustomRange = payrollUseCustomRange
        payrollViewModel.customStart = payrollStart
        payrollViewModel.customEnd = payrollEnd
        await payrollViewModel.loadSummary()
        
        guard let summary = payrollViewModel.summary else { return }
        
        // Autofill amount, date, vendor and notes
        amount = summary.totalCost
        // Date = end of the period (pay day), parsed as a local date to
        // avoid any timezone day-shift
        if let endDate = Self.dateOnlyFormatter.date(from: summary.period.endDate) {
            date = endDate
        }
        vendor = member.displayName
        description = "Nómina \(member.displayName)"
        notes = summary.expenseDetails
        payrollAutofilled = true
    }
    
    // MARK: - Populate Form
    
    private func populateForm(from expense: Expense) {
        selectedType = expense.type
        amount = expense.amountDouble
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
        guard let amountValue = amount,
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
