import Foundation

// MARK: - Reports ViewModel

@MainActor
class ReportsViewModel: ObservableObject {
    @Published var cogsReport: COGSReport?
    @Published var valuationReport: ValuationReport?
    @Published var profitMarginReport: ProfitMarginReport?
    @Published var profitLossReport: ProfitLossReport?
    @Published var adjustmentImpactReport: AdjustmentImpactReport?
    @Published var receivingSummaryReport: ReceivingSummaryReport?
    @Published var expenseSummary: ExpenseSummary?

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private let apiClient = APIClient.shared

    // Date range
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var endDate: Date = Date()

    private var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }

    // MARK: - COGS Report

    func loadCOGSReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ReportResponse<COGSReport> = try await apiClient.request(
                endpoint: .cogsReport,
                queryParams: params
            )
            cogsReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar reporte de costos"
            showError = true
        }
    }

    // MARK: - Valuation Report

    func loadValuationReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [:]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ReportResponse<ValuationReport> = try await apiClient.request(
                endpoint: .valuationReport,
                queryParams: params.isEmpty ? nil : params
            )
            valuationReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar reporte de valuación"
            showError = true
        }
    }

    // MARK: - Profit Margin Report

    func loadProfitMarginReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ReportResponse<ProfitMarginReport> = try await apiClient.request(
                endpoint: .profitMarginReport,
                queryParams: params
            )
            profitMarginReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar reporte de margen"
            showError = true
        }
    }

    // MARK: - Profit & Loss Report

    func loadProfitLossReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ReportResponse<ProfitLossReport> = try await apiClient.request(
                endpoint: .profitLossReport,
                queryParams: params
            )
            profitLossReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar reporte de P&G"
            showError = true
        }
    }

    // MARK: - Adjustment Impact Report

    func loadAdjustmentImpactReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ReportResponse<AdjustmentImpactReport> = try await apiClient.request(
                endpoint: .adjustmentImpactReport,
                queryParams: params
            )
            adjustmentImpactReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar reporte de impacto"
            showError = true
        }
    }

    // MARK: - Receiving Summary Report

    func loadReceivingSummaryReport(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate)
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ReportResponse<ReceivingSummaryReport> = try await apiClient.request(
                endpoint: .receivingSummaryReport,
                queryParams: params
            )
            receivingSummaryReport = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar resumen de recepciones"
            showError = true
        }
    }

    // MARK: - Expense Summary

    func loadExpenseSummary(locationId: String?) async {
        isLoading = true
        defer { isLoading = false }

        var params: [String: String] = [
            "startDate": dateFormatter.string(from: startDate),
            "endDate": dateFormatter.string(from: endDate),
            "includeMonthly": "true"
        ]
        if let locationId = locationId {
            params["locationId"] = locationId
        }

        do {
            let response: ExpenseSummaryResponse = try await apiClient.request(
                endpoint: .expenseSummary,
                queryParams: params
            )
            expenseSummary = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = "Error al cargar resumen de gastos"
            showError = true
        }
    }
}

// MARK: - Report Response

struct ReportResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
}
