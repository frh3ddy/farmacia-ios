import SwiftUI

// MARK: - Payroll View
// Shows a team member's shifts for the current week, a past week, or a custom
// date range — with totals (hours, worked days, cost) and the ability to
// adjust a shift's start/end time (persisted to Square).
//
// Timezone note: the backend returns durations already computed in minutes
// against the business timezone, so the totals never shift with the device
// timezone. Timestamps are parsed with their embedded RFC3339 offset.

struct PayrollView: View {
    @StateObject private var viewModel = PayrollViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.teamMembers.isEmpty && !viewModel.isLoadingMembers {
                    emptyTeamState
                } else {
                    content
                }
            }
            .navigationTitle("Nómina")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if viewModel.teamMembers.isEmpty {
                    await viewModel.loadTeamMembers()
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
    }
    
    // MARK: - States
    
    private var emptyTeamState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No hay empleados cargados")
                .foregroundColor(.secondary)
            Button("Cargar desde Square") {
                Task { await viewModel.loadTeamMembers() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    @ViewBuilder
    private var content: some View {
        List {
            // Employee picker
            Section("Empleado") {
                Picker("Empleado", selection: Binding(
                    get: { viewModel.selectedMember },
                    set: { member in
                        if let member {
                            Task { await viewModel.selectMember(member) }
                        }
                    }
                )) {
                    Text("Seleccionar...").tag(TeamMember?.none)
                    ForEach(viewModel.teamMembers) { member in
                        Text(member.displayName).tag(TeamMember?.some(member))
                    }
                }
            }
            
            if viewModel.selectedMember != nil {
                periodSection
                totalsSection
                shiftsSection
            }
        }
    }
    
    // MARK: - Period Selection
    
    private var periodSection: some View {
        Section("Periodo") {
            Toggle("Rango personalizado", isOn: Binding(
                get: { viewModel.useCustomRange },
                set: { newValue in
                    viewModel.useCustomRange = newValue
                    Task { await viewModel.loadSummary() }
                }
            ))
            
            if viewModel.useCustomRange {
                DatePicker("Desde", selection: $viewModel.customStart, displayedComponents: .date)
                    .onChange(of: viewModel.customStart) { _, _ in
                        Task { await viewModel.loadSummary() }
                    }
                DatePicker("Hasta", selection: $viewModel.customEnd, displayedComponents: .date)
                    .onChange(of: viewModel.customEnd) { _, _ in
                        Task { await viewModel.loadSummary() }
                    }
            } else {
                HStack {
                    Button {
                        viewModel.weekOffset += 1
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    if let period = viewModel.summary?.period {
                        Text("\(period.startDate)  –  \(period.endDate)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(viewModel.weekOffset == 0 ? "Semana actual" : "Hace \(viewModel.weekOffset) semana(s)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        if viewModel.weekOffset > 0 {
                            viewModel.weekOffset -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.weekOffset <= 0)
                }
            }
        }
    }
    
    // MARK: - Totals
    
    @ViewBuilder
    private var totalsSection: some View {
        if viewModel.isLoadingSummary {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        } else if let summary = viewModel.summary {
            Section("Totales") {
                HStack {
                    Label("Días trabajados", systemImage: "calendar")
                    Spacer()
                    Text("\(summary.workedDays)")
                        .bold()
                }
                HStack {
                    Label("Horas totales", systemImage: "clock")
                    Spacer()
                    Text(summary.formattedTotalTime)
                        .bold()
                }
                HStack {
                    Label("Tarifa por hora", systemImage: "dollarsign.circle")
                    Spacer()
                    Text("$\(String(format: "%.2f", summary.hourlyRate)) \(summary.currency)")
                        .bold()
                }
                HStack {
                    Label("Total a pagar", systemImage: "banknote")
                    Spacer()
                    Text(summary.formattedTotalCost)
                        .bold()
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Shifts
    
    @ViewBuilder
    private var shiftsSection: some View {
        if let summary = viewModel.summary, !summary.shifts.isEmpty {
            Section("Turnos (\(summary.shifts.count))") {
                ForEach(summary.shifts) { shift in
                    ShiftRow(shift: shift, viewModel: viewModel)
                }
            }
        } else if let summary = viewModel.summary, summary.shifts.isEmpty, !viewModel.isLoadingSummary {
            Section {
                Text("Sin turnos en este periodo")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Shift Row

private struct ShiftRow: View {
    let shift: ShiftSummary
    @ObservedObject var viewModel: PayrollViewModel
    @State private var showEditor = false
    
    var body: some View {
        Button {
            showEditor = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(shift.date)
                            .font(.subheadline)
                            .bold()
                        if shift.isOpen {
                            Text("EN CURSO")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(timeRangeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(shift.formattedDuration)
                        .font(.subheadline)
                        .bold()
                    Text("$\(String(format: "%.2f", shift.cost))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditor) {
            ShiftEditorSheet(shift: shift, viewModel: viewModel)
        }
    }
    
    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let start = shift.startDateValue.map { formatter.string(from: $0) } ?? "—"
        let end = shift.endDateValue.map { formatter.string(from: $0) } ?? "en curso"
        return "\(start) – \(end)"
    }
}

// MARK: - Shift Editor Sheet

private struct ShiftEditorSheet: View {
    let shift: ShiftSummary
    @ObservedObject var viewModel: PayrollViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasEnd: Bool
    
    init(shift: ShiftSummary, viewModel: PayrollViewModel) {
        self.shift = shift
        self.viewModel = viewModel
        _startDate = State(initialValue: shift.startDateValue ?? Date())
        _endDate = State(initialValue: shift.endDateValue ?? Date())
        _hasEnd = State(initialValue: shift.endDateValue != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Turno del \(shift.date)") {
                    DatePicker("Entrada", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Tiene salida", isOn: $hasEnd)
                    if hasEnd {
                        DatePicker("Salida", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section {
                    HStack {
                        Text("Duración")
                        Spacer()
                        Text(durationText)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Ajustar turno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        Task {
                            let ok = await viewModel.updateShiftTimes(
                                shiftId: shift.shiftId,
                                startAt: startDate,
                                endAt: hasEnd ? endDate : nil
                            )
                            if ok { dismiss() }
                        }
                    }
                    .disabled(viewModel.isSavingShift)
                }
            }
        }
    }
    
    private var durationText: String {
        let end = hasEnd ? endDate : Date()
        let minutes = max(0, Int(end.timeIntervalSince(startDate) / 60))
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

// MARK: - Preview

#Preview {
    PayrollView()
}
