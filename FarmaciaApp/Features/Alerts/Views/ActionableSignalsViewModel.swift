import Foundation

// MARK: - Actionable Signals ViewModel

@MainActor
class ActionableSignalsViewModel: ObservableObject {
    @Published var signals: [ActionableSignal] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    func loadSignals(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: ActionableSignalsResponse = try await apiClient.request(
                endpoint: .agingSignals,
                queryParams: [
                    "locationId": locationId,
                    "limit": "20"
                ]
            )
            signals = response.signals
        } catch {
            // Silent fail — signals are supplementary
            print("Failed to load actionable signals: \(error)")
            signals = []
        }
    }
}

