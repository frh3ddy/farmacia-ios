import Foundation
import FarmaciaKit

// MARK: - Dashboard View Model

@MainActor
class DashboardViewModel: ObservableObject {
    @Published private(set) var dashboardReport: DashboardReport?
    /// The selection `dashboardReport` was loaded for.
    @Published private(set) var reportSelection: DashboardSelection?
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var showLocationSwitcher = false
    @Published var selectedPeriod: DashboardPeriod = .default
    /// Changing this re-runs the view's load task (refresh button, Reintentar).
    @Published var reloadID = UUID()
    /// Today's local day; updated when the app returns to the foreground so "Hoy" rolls over.
    @Published var today = LocalDay.string(from: Date())
    
    private let apiClient = APIClient.shared
    
    func reload() {
        reloadID = UUID()
    }
    
    /// What's on screen now: the period, the branch and the day.
    var currentSelection: DashboardSelection {
        DashboardSelection(period: selectedPeriod, locationId: AuthManager.shared.currentLocation?.id, day: today)
    }
    
    /// The report, only while it belongs to the current selection — never another branch's
    /// or period's numbers under this one's label.
    var visibleReport: DashboardReport? {
        reportSelection == currentSelection ? dashboardReport : nil
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
        
        let selection = currentSelection
        let isStillSelected = { [weak self] in
            !Task.isCancelled && self?.currentSelection == selection
        }
        let (startDay, endDay) = selection.period.days()
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
            reportSelection = selection
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

/// The period, branch and day a dashboard report answers.
struct DashboardSelection: Equatable {
    let period: DashboardPeriod
    let locationId: String?
    let day: String
}

/// What the dashboard's load task depends on; a change cancels the running load.
struct DashboardLoadKey: Equatable {
    let selection: DashboardSelection
    let reloadID: UUID
}
