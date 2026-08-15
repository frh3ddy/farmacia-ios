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
        Group {
            if viewModel.teamMembers.isEmpty && !viewModel.isLoadingMembers {
                emptyTeamState
            } else {
                content
            }
        }
        .navigationTitle("Nómina")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let selectedMember = viewModel.selectedMember {
                ToolbarItem(placement: .topBarTrailing) {
                    memberMenu(selectedMember: selectedMember)
                }
            }
        }
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

    // MARK: - States

    private var emptyTeamState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No hay empleados cargados")
                .foregroundStyle(.secondary)
            Button("Cargar desde Square") {
                Task { await viewModel.loadTeamMembers() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.selectedMember == nil {
            if viewModel.isLoadingMembers {
                loadingMembersState
            } else {
                memberList
            }
        } else {
            List {
                periodSection
                totalsSection
                shiftsSection
            }
        }
    }

    // MARK: - Member Menu (toolbar)

    private func memberMenu(selectedMember: TeamMember) -> some View {
        Menu {
            Picker("Empleado", selection: Binding(
                get: { selectedMember.id },
                set: { newId in
                    if let member = viewModel.teamMembers.first(where: { $0.id == newId }) {
                        Task { await viewModel.selectMember(member) }
                    }
                }
            )) {
                ForEach(viewModel.teamMembers) { member in
                    Text(member.displayName).tag(member.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedMember.displayName)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
        }
    }

    private var loadingMembersState: some View {
        List(0..<6, id: \.self) { _ in
            HStack {
                Text("               ")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .redacted(reason: .placeholder)
        }
    }

    // MARK: - Member Selection

    /// No member selected yet: list everyone right away instead of making the
    /// user open a Picker menu first — one tap to pick, matching how few team
    /// members a typical location has.
    private var memberList: some View {
        List(viewModel.teamMembers) { member in
            Button {
                Task { await viewModel.selectMember(member) }
            } label: {
                HStack {
                    Text(member.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Semana anterior")

                    Spacer()
                    if let period = viewModel.summary?.period {
                        Text(PayrollDateFormatting.periodLabel(start: period.startDate, end: period.endDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(viewModel.weekOffset == 0 ? "Semana actual" : "Hace \(viewModel.weekOffset) semana(s)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    Button {
                        if viewModel.weekOffset > 0 {
                            viewModel.weekOffset -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.weekOffset <= 0)
                    .accessibilityLabel("Semana siguiente")
                }
            }
        }
    }
    
    // MARK: - Totals
    
    @ViewBuilder
    private var totalsSection: some View {
        if viewModel.isLoadingSummary {
            Section("Totales") {
                ForEach(0..<4, id: \.self) { _ in
                    HStack {
                        Label("Días trabajados", systemImage: "calendar")
                        Spacer()
                        Text("00")
                            .bold()
                    }
                    .redacted(reason: .placeholder)
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
                        .foregroundStyle(.green)
                }
            }
        }
    }
    
    // MARK: - Shifts
    
    @ViewBuilder
    private var shiftsSection: some View {
        if viewModel.isLoadingSummary {
            Section("Turnos") {
                ForEach(0..<3, id: \.self) { _ in
                    ShiftRowPlaceholder()
                }
            }
        } else if let summary = viewModel.summary, !summary.shifts.isEmpty {
            Section("Turnos (\(summary.shifts.count))") {
                ForEach(summary.shifts) { shift in
                    ShiftRow(shift: shift, viewModel: viewModel)
                }
            }
        } else if let summary = viewModel.summary, summary.shifts.isEmpty, !viewModel.isLoadingSummary {
            Section {
                Text("Sin turnos en este periodo")
                    .foregroundStyle(.secondary)
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
                        Text(PayrollDateFormatting.shiftLabel(from: shift.date))
                            .font(.subheadline)
                            .bold()
                        if shift.isOpen {
                            Text("EN CURSO")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(timeRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(shift.formattedDuration)
                        .font(.subheadline)
                        .bold()
                    Text("$\(String(format: "%.2f", shift.cost))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct ShiftRowPlaceholder: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lunes 00/00")
                    .font(.subheadline)
                    .bold()
                Text("00:00 – 00:00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("0:00")
                    .font(.subheadline)
                    .bold()
                Text("$0.00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .redacted(reason: .placeholder)
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
                Section("Turno del \(PayrollDateFormatting.fullLabel(from: shift.date))") {
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ajustar turno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
    }

    private var durationText: String {
        let end = hasEnd ? endDate : Date()
        let minutes = max(0, Int(end.timeIntervalSince(startDate) / 60))
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}

// MARK: - Date Formatting Helpers

/// The backend returns business-local dates as `YYYY-MM-DD` strings (already
/// computed in the business timezone). We parse them as plain local dates with
/// no time component, so the device timezone can never shift the displayed day.
private enum PayrollDateFormatting {
    static let input: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
    
    static let dayName: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "EEEE"
        f.timeZone = TimeZone.current
        return f
    }()
    
    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "dd/MM"
        f.timeZone = TimeZone.current
        return f
    }()
    
    static let dayMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "dd/MM/yyyy"
        f.timeZone = TimeZone.current
        return f
    }()
    
    /// "Lunes 10/08" — Spanish day name + DD/MM, no year
    static func shiftLabel(from dateString: String) -> String {
        guard let date = input.date(from: dateString) else { return dateString }
        let name = dayName.string(from: date)
        return "\(name.prefix(1).uppercased())\(name.dropFirst()) \(dayMonth.string(from: date))"
    }
    
    /// "10/08 – 16/08"; adds the year only when the range falls (fully or
    /// partially) outside the current year, e.g. "28/12/2025 – 03/01/2026"
    static func periodLabel(start: String, end: String) -> String {
        guard let startDate = input.date(from: start),
              let endDate = input.date(from: end) else {
            return "\(start) – \(end)"
        }
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let withinCurrentYear =
            calendar.component(.year, from: startDate) == currentYear &&
            calendar.component(.year, from: endDate) == currentYear
        if withinCurrentYear {
            return "\(dayMonth.string(from: startDate)) – \(dayMonth.string(from: endDate))"
        }
        return "\(dayMonthYear.string(from: startDate)) – \(dayMonthYear.string(from: endDate))"
    }
    
    /// "Lunes, 10 de agosto de 2026" — used in the shift editor for full context
    static func fullLabel(from dateString: String) -> String {
        guard let date = input.date(from: dateString) else { return dateString }
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateStyle = .full
        f.timeZone = TimeZone.current
        let text = f.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PayrollView()
    }
}
