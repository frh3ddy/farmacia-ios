import SwiftUI

// MARK: - Inventory View

struct InventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedSegment: InventorySegment = .receive

    // Shared across all three segments so switching tabs doesn't tear down
    // and rebuild a fresh view model (which discarded loaded data and
    // re-fired every network call each time the user tapped a segment).
    @StateObject private var viewModel = InventoryViewModel()

    enum InventorySegment: String, CaseIterable {
        case receive = "Recibir"
        case ajustes = "Ajustes"
        case history = "Historial"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Inventario", selection: $selectedSegment) {
                    ForEach(InventorySegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on segment
                switch selectedSegment {
                case .receive:
                    if authManager.canManageInventory {
                        ReceiveInventoryView(viewModel: viewModel)
                    } else {
                        noPermissionView
                    }
                case .ajustes:
                    if authManager.canManageInventory {
                        AdjustmentsListView(viewModel: viewModel)
                    } else {
                        noPermissionView
                    }
                case .history:
                    ReceivingHistoryView(viewModel: viewModel)
                }
            }
            .navigationTitle("Inventario")
            .task {
                await viewModel.loadProducts()
                await viewModel.loadSuppliers()
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadReceivings(locationId: locationId)
                    await viewModel.loadAdjustments(locationId: locationId)
                }
            }
        }
    }

    private var noPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Acceso Restringido")
                .font(.headline)

            Text("No tienes permiso para acceder a esta función.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    InventoryView()
        .environmentObject(AuthManager.shared)
}
