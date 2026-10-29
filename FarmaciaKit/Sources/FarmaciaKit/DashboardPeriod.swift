import Foundation

// MARK: - Dashboard Period
//
// Calendar periods, not rolling windows: monthly expenses (rent) and weekly
// payroll land whole in a period, so net profit doesn't jump with the window.
// Weeks run Monday–Sunday like payroll (farmacia-ops labor.service), whatever
// the device locale (es_MX calendars start on Sunday). Days are inclusive
// YYYY-MM-DD, which the API reads as whole Mexico City days.

public enum DashboardPeriod: CaseIterable, Sendable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case thisYear

    public static let `default`: DashboardPeriod = .thisMonth

    public var displayName: String {
        switch self {
        case .today: return "Hoy"
        case .yesterday: return "Ayer"
        case .thisWeek: return "Esta Semana"
        case .lastWeek: return "Semana Pasada"
        case .thisMonth: return "Este Mes"
        case .lastMonth: return "Mes Pasado"
        case .thisYear: return "Este Año"
        }
    }

    /// The first and last day of the period, inclusive, in the calendar's time zone.
    public func days(now: Date = Date(), calendar: Calendar = .current) -> (start: String, end: String) {
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: now)

        func adding(_ component: Calendar.Component, _ value: Int, to date: Date) -> Date {
            cal.date(byAdding: component, value: value, to: date) ?? date
        }
        func start(of component: Calendar.Component) -> Date {
            cal.dateInterval(of: component, for: today)?.start ?? today
        }

        let first: Date
        let last: Date
        switch self {
        case .today:
            (first, last) = (today, today)
        case .yesterday:
            let yesterday = adding(.day, -1, to: today)
            (first, last) = (yesterday, yesterday)
        case .thisWeek:
            (first, last) = (start(of: .weekOfYear), today)
        case .lastWeek:
            let monday = start(of: .weekOfYear)
            (first, last) = (adding(.day, -7, to: monday), adding(.day, -1, to: monday))
        case .thisMonth:
            (first, last) = (start(of: .month), today)
        case .lastMonth:
            let firstOfMonth = start(of: .month)
            (first, last) = (adding(.month, -1, to: firstOfMonth), adding(.day, -1, to: firstOfMonth))
        case .thisYear:
            (first, last) = (start(of: .year), today)
        }
        return (LocalDay.string(from: first, timeZone: cal.timeZone), LocalDay.string(from: last, timeZone: cal.timeZone))
    }
}
