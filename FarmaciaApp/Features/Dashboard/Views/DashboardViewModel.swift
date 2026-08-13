import Foundation

// MARK: - Date Range Enum

enum DashboardDateRange: CaseIterable {
    case today
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case thisYear
    
    var displayName: String {
        switch self {
        case .today: return "Hoy"
        case .last7Days: return "Últimos 7 Días"
        case .last30Days: return "Últimos 30 Días"
        case .thisMonth: return "Este Mes"
        case .lastMonth: return "Mes Pasado"
        case .thisYear: return "Este Año"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
            
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
            
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            return (start, now)
            
        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (start, now)
            
        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
            let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart)!
            return (lastMonthStart, lastMonthEnd)
            
        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (start, now)
        }
    }
}


// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboardReport: DashboardReport?
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showLocationSwitcher = false
    @Published var selectedDateRange: DashboardDateRange = .last30Days
    
    private let apiClient = APIClient.shared
    
    func loadDashboard() async {
        isLoading = true
        error = nil
        
        do {
            // Get current location
            guard let locationId = AuthManager.shared.currentLocation?.id else {
                error = NetworkError.serverError(message: "No se ha seleccionado ubicación")
                isLoading = false
                return
            }
            
            // Get date range
            let (startDate, endDate) = selectedDateRange.dateRange
            
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate]
            
            let queryParams = [
                "locationId": locationId,
                "startDate": dateFormatter.string(from: startDate),
                "endDate": dateFormatter.string(from: endDate)
            ]
            
            dashboardReport = try await apiClient.request(
                endpoint: .dashboardReport,
                queryParams: queryParams
            )
        } catch let networkError as NetworkError {
            error = networkError
        } catch {
            self.error = NetworkError.unknown(error)
        }
        
        isLoading = false
    }
}

