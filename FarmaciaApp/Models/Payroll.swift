import Foundation

// MARK: - Team Member (from Square)

struct TeamMember: Codable, Identifiable, Hashable {
    let id: String
    let givenName: String
    let familyName: String
    let fullName: String
    let status: String?
    
    var displayName: String {
        fullName.isEmpty ? "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces) : fullName
    }
}

struct TeamMembersResponse: Decodable {
    let success: Bool
    let count: Int
    let data: [TeamMember]
}

// MARK: - Payroll Summary

struct PayrollPeriod: Codable, Hashable {
    let startDate: String  // YYYY-MM-DD
    let endDate: String    // YYYY-MM-DD
}

struct ShiftSummary: Codable, Identifiable, Hashable {
    let shiftId: String
    let date: String            // Local date YYYY-MM-DD
    let startAt: String         // RFC3339 with location offset
    let endAt: String?          // nil while shift is OPEN
    let status: String?
    let workedMinutes: Int
    let hours: Int
    let minutes: Int
    let hourlyRate: Double
    let currency: String
    let cost: Double
    let jobTitle: String?
    
    var id: String { shiftId }
    
    var isOpen: Bool { endAt == nil || status == "OPEN" }
    
    /// "HH:mm" formatted duration, e.g. "8:05"
    var formattedDuration: String {
        String(format: "%d:%02d", hours, minutes)
    }
    
    /// Date object parsed from the RFC3339 start timestamp (offset-aware,
    /// so it is safe regardless of the device timezone).
    var startDateValue: Date? {
        Self.rfc3339Formatter.date(from: startAt)
    }
    
    var endDateValue: Date? {
        guard let endAt else { return nil }
        return Self.rfc3339Formatter.date(from: endAt)
    }
    
    static let rfc3339Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

struct PayrollSummary: Codable {
    let teamMemberId: String
    let period: PayrollPeriod
    let hourlyRate: Double
    let currency: String
    let totalWorkedMinutes: Int
    let totalHours: Int
    let totalMinutes: Int
    let workedDays: Int
    let totalCost: Double
    let shifts: [ShiftSummary]
    
    /// "HH:mm" formatted total, e.g. "42:30"
    var formattedTotalTime: String {
        String(format: "%d:%02d", totalHours, totalMinutes)
    }
    
    var formattedTotalCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: totalCost)) ?? "$\(totalCost)"
    }
    
    /// Multiline details for the expense form (hours, worked days, rate, period)
    var expenseDetails: String {
        var lines: [String] = []
        lines.append("Periodo: \(period.startDate) a \(period.endDate)")
        lines.append("Días trabajados: \(workedDays)")
        lines.append("Horas totales: \(formattedTotalTime)")
        lines.append("Tarifa por hora: $\(String(format: "%.2f", hourlyRate)) \(currency)")
        lines.append("Turnos: \(shifts.count)")
        return lines.joined(separator: "\n")
    }
}

struct PayrollSummaryResponse: Decodable {
    let success: Bool
    let data: PayrollSummary
}

// MARK: - Shift Update

struct UpdateShiftTimesRequest: Encodable {
    let startAt: String?
    let endAt: String?
}

struct ShiftUpdateResponse: Decodable {
    let success: Bool
    let message: String
    let data: ShiftSummary
}
