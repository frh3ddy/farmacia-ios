import SwiftUI

// MARK: - Receiving History View

struct ReceivingHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel

    var body: some View {
        // Always show List to prevent refresh control issues
        List {
            if viewModel.recentReceivings.isEmpty {
                Section {
                    if viewModel.isLoadingReceivings {
                        HStack {
                            Spacer()
                            ProgressView("Cargando historial...")
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            Text("No hay historial de recepciones")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowBackground(Color.clear)
                    }
                }
            } else {
                ForEach(viewModel.recentReceivings) { receiving in
                    ReceivingRow(receiving: receiving)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadReceivings(locationId: locationId)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Ocurrió un error")
        }
    }
}
