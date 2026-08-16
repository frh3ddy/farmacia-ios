import SwiftUI

// MARK: - Device Management View (OWNER only)
// Lists active devices at the current location and lets an owner revoke one
// remotely — e.g. a lost or stolen iPad. Scoped to `authManager.currentLocation`,
// same as the rest of the app; use "Cambiar Ubicación" in Settings to manage
// devices at a different location instead of duplicating a picker here.

struct DeviceManagementView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = DeviceManagementViewModel()

    var body: some View {
        List {
            if viewModel.devices.isEmpty && !viewModel.isLoading {
                Text("No hay dispositivos activos en esta ubicación.")
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.devices) { device in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.name)
                            .font(.headline)
                        Spacer()
                        Text(device.type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let lastActiveAt = device.lastActiveAt {
                        Text("Última actividad: \(lastActiveAt, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sin actividad registrada")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .swipeActions {
                    Button(role: .destructive) {
                        viewModel.confirmDeactivate(device)
                    } label: {
                        Label("Desactivar", systemImage: "xmark.shield")
                    }
                }
            }
        }
        .navigationTitle("Dispositivos")
        .overlay {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView()
            }
        }
        .task {
            await viewModel.loadDevices(authManager: authManager)
        }
        .refreshable {
            await viewModel.loadDevices(authManager: authManager)
        }
        .alert("Desactivar Dispositivo", isPresented: $viewModel.showConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Desactivar", role: .destructive) {
                Task { await viewModel.deactivate() }
            }
        } message: {
            Text("\"\(viewModel.pendingDevice?.name ?? "")\" cerrará sesión y necesitará credenciales de dueño/gerente para reactivarse.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

// MARK: - Device Management View Model

@MainActor
class DeviceManagementViewModel: ObservableObject {
    @Published var devices: [ManagedDevice] = []
    @Published var isLoading = false
    @Published var showConfirm = false
    @Published var showError = false
    @Published var errorMessage = ""
    private(set) var pendingDevice: ManagedDevice?

    private let apiClient = APIClient.shared

    func loadDevices(authManager: AuthManager) async {
        guard let locationId = authManager.currentLocation?.id else { return }
        isLoading = true
        do {
            let response: DeviceListResponse = try await apiClient.request(
                endpoint: .listDevices,
                queryParams: ["locationId": locationId]
            )
            devices = response.data
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "No se pudieron cargar los dispositivos"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    func confirmDeactivate(_ device: ManagedDevice) {
        pendingDevice = device
        showConfirm = true
    }

    func deactivate() async {
        guard let device = pendingDevice else { return }
        do {
            try await apiClient.requestVoid(endpoint: .deactivateDevice(deviceId: device.id))
            devices.removeAll { $0.id == device.id }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "No se pudo desactivar el dispositivo"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        pendingDevice = nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DeviceManagementView()
    }
    .environmentObject(AuthManager.shared)
}
