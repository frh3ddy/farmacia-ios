import Foundation

// MARK: - Payroll ViewModel

/// Backing state for the payroll (nómina) features:
/// - Team members pulled from Square
/// - Payroll summary (hours, worked days, cost) for a week or custom date range
/// - Shift start/end time adjustments
///
/// Timezone note: the backend computes periods and durations against the
/// business timezone (America/Mexico_City) and returns durations as
/// minutes/hours — so nothing here depends on the device timezone. Dates are
/// only converted to local `Date` values for display/editing, using the
/// offset embedded in the RFC3339 timestamps.
@MainActor
class PayrollViewModel: ObservableObject {
    @Published var teamMembers: [TeamMember] = []
    @Published var selectedMember: TeamMember?
    @Published var summary: PayrollSummary?
    @Published var isLoadingMembers = false
    @Published var isLoadingSummary = false
    @Published var isSavingShift = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    enum Granularity {
        case day, week, month, custom
    }

    /// Period selection mode: a day, week, or month (navigated via `periodOffset`), or a custom range.
    @Published var granularity: Granularity = .week
    /// Number of periods (in the active granularity's unit) before the current one. 0 = current.
    @Published var periodOffset = 0 {
        didSet { if granularity != .custom { Task { await loadSummary() } } }
    }
    @Published var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var customEnd = Date()

    private let apiClient = APIClient.shared

    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    /// The day represented by `periodOffset` when granularity is `.day`.
    var selectedDay: Date {
        Calendar.current.date(byAdding: .day, value: -periodOffset, to: Date()) ?? Date()
    }

    /// The first day of the month represented by `periodOffset` when granularity is `.month`.
    var selectedMonthStart: Date {
        let calendar = Calendar.current
        let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: -periodOffset, to: startOfThisMonth) ?? startOfThisMonth
    }

    private var selectedMonthEnd: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: selectedMonthStart) ?? selectedMonthStart
    }
    
    // MARK: - Team Members
    
    func loadTeamMembers() async {
        isLoadingMembers = true
        defer { isLoadingMembers = false }
        
        do {
            let response: TeamMembersResponse = try await apiClient.request(
                endpoint: .laborTeamMembers
            )
            teamMembers = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar el equipo"
            showError = true
        }
    }
    
    func selectMember(_ member: TeamMember) async {
        selectedMember = member
        await loadSummary()
    }
    
    // MARK: - Payroll Summary
    
    func loadSummary() async {
        guard let member = selectedMember else { return }
        
        isLoadingSummary = true
        defer { isLoadingSummary = false }
        
        var params: [String: String] = ["teamMemberId": member.id]
        switch granularity {
        case .week:
            params["weekOffset"] = String(periodOffset)
        case .day:
            let day = Self.dateOnlyFormatter.string(from: selectedDay)
            params["startDate"] = day
            params["endDate"] = day
        case .month:
            params["startDate"] = Self.dateOnlyFormatter.string(from: selectedMonthStart)
            params["endDate"] = Self.dateOnlyFormatter.string(from: selectedMonthEnd)
        case .custom:
            params["startDate"] = Self.dateOnlyFormatter.string(from: customStart)
            params["endDate"] = Self.dateOnlyFormatter.string(from: customEnd)
        }
        
        do {
            let response: PayrollSummaryResponse = try await apiClient.request(
                endpoint: .laborPayrollSummary,
                queryParams: params
            )
            summary = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar la nómina"
            showError = true
        }
    }
    
    // MARK: - Shift Time Adjustment
    
    /// Persists new start/end times for a shift.
    /// The dates passed in must carry the correct wall-clock time; they are
    /// serialized with the device's offset which Square interprets correctly.
    func updateShiftTimes(shiftId: String, startAt: Date, endAt: Date?) async -> Bool {
        isSavingShift = true
        defer { isSavingShift = false }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let request = UpdateShiftTimesRequest(
            startAt: formatter.string(from: startAt),
            endAt: endAt.map { formatter.string(from: $0) }
        )
        
        do {
            let response: ShiftUpdateResponse = try await apiClient.request(
                endpoint: .laborUpdateShift(id: shiftId),
                body: request
            )
            
            // Patch the shift in the local summary so totals refresh instantly
            if let current = summary,
               let index = current.shifts.firstIndex(where: { $0.shiftId == shiftId }) {
                var patchedShifts = current.shifts
                patchedShifts[index] = response.data
                // Recompute totals from the patched shifts
                let totalMinutes = patchedShifts.reduce(0) { $0 + $1.workedMinutes }
                let workedDays = Set(patchedShifts.map { $0.date }).count
                let cost = (Double(totalMinutes) / 60.0) * current.hourlyRate
                summary = PayrollSummary(
                    teamMemberId: current.teamMemberId,
                    period: current.period,
                    hourlyRate: current.hourlyRate,
                    currency: current.currency,
                    totalWorkedMinutes: totalMinutes,
                    totalHours: totalMinutes / 60,
                    totalMinutes: totalMinutes % 60,
                    workedDays: workedDays,
                    totalCost: (cost * 100).rounded() / 100,
                    shifts: patchedShifts
                )
            }
            return true
        } catch NetworkError.queuedForSync {
            // No server response to patch the local summary with (workedMinutes/
            // cost are server-computed) — leave the old time showing rather
            // than guess, same call as inventory quantities.
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Error al actualizar el turno"
            showError = true
            return false
        }
    }

    // MARK: - Shift Deletion

    /// Deletes a shift entirely (e.g. an accidental clock-in) and removes it
    /// from the local summary so totals refresh instantly.
    func deleteShift(shiftId: String) async -> Bool {
        isSavingShift = true
        defer { isSavingShift = false }

        do {
            try await apiClient.requestVoid(endpoint: .laborDeleteShift(id: shiftId))
            patchSummaryAfterDelete(shiftId: shiftId)
            return true
        } catch NetworkError.queuedForSync {
            // Deletion doesn't need a server response to apply locally —
            // safe to reflect immediately, same reasoning as EditPriceView.
            patchSummaryAfterDelete(shiftId: shiftId)
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
            return false
        } catch {
            errorMessage = "Error al eliminar el turno"
            showError = true
            return false
        }
    }

    private func patchSummaryAfterDelete(shiftId: String) {
        guard let current = summary else { return }
        let patchedShifts = current.shifts.filter { $0.shiftId != shiftId }
        let totalMinutes = patchedShifts.reduce(0) { $0 + $1.workedMinutes }
        let workedDays = Set(patchedShifts.map { $0.date }).count
        let cost = (Double(totalMinutes) / 60.0) * current.hourlyRate
        summary = PayrollSummary(
            teamMemberId: current.teamMemberId,
            period: current.period,
            hourlyRate: current.hourlyRate,
            currency: current.currency,
            totalWorkedMinutes: totalMinutes,
            totalHours: totalMinutes / 60,
            totalMinutes: totalMinutes % 60,
            workedDays: workedDays,
            totalCost: (cost * 100).rounded() / 100,
            shifts: patchedShifts
        )
    }
}
