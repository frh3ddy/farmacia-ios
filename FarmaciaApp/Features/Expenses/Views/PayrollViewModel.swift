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
    
    /// Period selection mode: current week (default), past weeks, or custom range
    @Published var weekOffset = 0 {
        didSet { if !useCustomRange { Task { await loadSummary() } } }
    }
    @Published var useCustomRange = false
    @Published var customStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var customEnd = Date()
    
    private let apiClient = APIClient.shared
    
    private static let dateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
    
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
        if useCustomRange {
            params["startDate"] = Self.dateOnlyFormatter.string(from: customStart)
            params["endDate"] = Self.dateOnlyFormatter.string(from: customEnd)
        } else {
            params["weekOffset"] = String(weekOffset)
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
}
