import Foundation
import FarmaciaKit

// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboardReport: DashboardReport?
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showLocationSwitcher = false
    @Published var selectedPeriod: DashboardPeriod = .default
    /// Changing this re-runs the view's load task (refresh button, Reintentar).
    @Published var reloadID = UUID()
    
    private let apiClient = APIClient.shared
    
    func reload() {
        reloadID = UUID()
    }
    
    /// Runs inside the view's `.task(id:)` (a newer period, location or reload cancels it)
    /// and from pull-to-refresh (which nothing cancels). Either way a load only writes its
    /// result if it wasn't cancelled and still matches what's selected.
    func loadDashboard() async {
        guard let locationId = AuthManager.shared.currentLocation?.id else {
            error = NetworkError.serverError(message: "No se ha seleccionado ubicación")
            return
        }
        
        isLoading = true
        error = nil
        
        let period = selectedPeriod
        let isStillSelected = { [weak self] in
            !Task.isCancelled && self?.selectedPeriod == period && AuthManager.shared.currentLocation?.id == locationId
        }
        let (startDay, endDay) = period.days()
        let queryParams = [
            "locationId": locationId,
            "startDate": startDay,
            "endDate": endDay
        ]
        
        do {
            let report: DashboardReport = try await apiClient.request(
                endpoint: .dashboardReport,
                queryParams: queryParams
            )
            guard isStillSelected() else { return }
            dashboardReport = report
        } catch NetworkError.cancelled {
            return
        } catch is CancellationError {
            return
        } catch let networkError as NetworkError {
            guard isStillSelected() else { return }
            error = networkError
        } catch {
            guard isStillSelected() else { return }
            self.error = NetworkError.unknown(error)
        }
        
        isLoading = false
    }
}

/// What the dashboard's load task depends on; a change cancels the running load.
struct DashboardLoadKey: Equatable {
    let period: DashboardPeriod
    let locationId: String?
    let reloadID: UUID
}
