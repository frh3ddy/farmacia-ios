import SwiftUI
import FarmaciaKit

// MARK: - Conteo inicial (Settings, owner)
//
// Starts and ends the store's Conteo inicial (tasks/opening-count-epic.md). While
// it's open, every count at the store is a Conteo inicial: it fixes the stock the
// migration loaded without counting as shrinkage.

struct OpeningCountSection: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var session: StockCountSession?
    @State private var loaded = false
    /// The store `session` belongs to: a switch clears it, so another store's count (and its Terminar) never shows.
    @State private var loadedLocationId: String?
    @State private var loadFailed = false
    @State private var isWorking = false
    @State private var confirmStart = false
    @State private var confirmEnd = false
    @State private var error: String? {
        didSet { showsError = error != nil }
    }
    @State private var showsError = false

    var body: some View {
        Section {
            if let session {
                LabeledContent("Iniciado", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Productos contados", value: "\(session.countedProducts)")
                NavigationLink("Ver no contados") {
                    UncountedListView(sessionId: session.id)
                }
                Button("Terminar conteo", role: .destructive) { confirmEnd = true }
                    .disabled(isWorking)
            } else if loaded {
                Button("Iniciar conteo inicial") { confirmStart = true }
                    .disabled(isWorking)
            } else if loadFailed {
                Button("Reintentar") { Task { await load() } }
            } else {
                ProgressView()
            }
        } header: {
            Text("Conteo inicial")
        } footer: {
            Text(session == nil
                 ? "Para corregir las existencias que dejó la migración sin afectar la utilidad."
                 : "Cada conteo en esta sucursal se guarda como Conteo inicial y no cuenta como merma.")
        }
        // Reloads each time Ajustes reappears, e.g. back from the list.
        .task(id: authManager.currentLocation?.id) { await load() }
        .alert("¿Iniciar conteo inicial?", isPresented: $confirmStart) {
            Button("Cancelar", role: .cancel) {}
            Button("Iniciar") { Task { await run(.stockCountStart) } }
        } message: {
            Text("Mientras esté abierto, los conteos en \(authManager.currentLocation?.name ?? "esta sucursal") corrigen existencias sin contar como merma. Ventas e ingresos no cambian.")
        }
        .alert("¿Terminar conteo inicial?", isPresented: $confirmEnd) {
            Button("Cancelar", role: .cancel) {}
            Button("Terminar", role: .destructive) {
                if let id = session?.id { Task { await run(.stockCountEnd(id: id)) } }
            }
        } message: {
            Text("Los conteos después de terminar vuelven a ser Corrección de Conteo. Revisa antes los no contados.")
        }
        .alert("No se pudo completar", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    private func load() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        if loadedLocationId != locationId {
            session = nil
            loaded = false
        }
        loadFailed = false
        do {
            let response: APIResponse<StockCountSession> = try await APIClient.shared.request(
                endpoint: .stockCountActive,
                queryParams: ["locationId": locationId]
            )
            session = response.data
            loaded = true
            loadedLocationId = locationId
        } catch {
            // No alert: this reloads each time Ajustes appears. A first load that fails shows
            // Reintentar; a reload that fails keeps what's on screen for this store.
            guard !Task.isCancelled else { return }
            loadFailed = !loaded
        }
    }

    /// Writes name the store shown, so they never land on the login session's store if the two differ.
    private var locationBody: [String: String]? {
        authManager.currentLocation.map { ["locationId": $0.id] }
    }

    private func run(_ endpoint: APIEndpoint) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await APIClient.shared.requestVoid(endpoint: endpoint, body: locationBody)
            await load()
        } catch {
            self.error = (error as? NetworkError)?.errorDescription ?? "No se pudo completar"
        }
    }
}

// MARK: - No contados

/// Products still showing stock that the Conteo inicial hasn't counted, to set to 0.
struct UncountedListView: View {
    let sessionId: String

    @EnvironmentObject private var authManager: AuthManager
    @State private var rows: [UncountedProduct]?
    @State private var zeroing: Set<String> = []
    /// "Poniendo en 0… 150 de 1900" while a long run goes batch by batch.
    @State private var zeroProgress: String?
    @State private var confirmAll = false
    @State private var loadFailed = false
    @State private var error: String? {
        didSet { showsError = error != nil }
    }
    @State private var showsError = false

    var body: some View {
        List {
            if let rows, rows.isEmpty {
                ContentUnavailableView(
                    "Todo contado",
                    systemImage: "checkmark.circle",
                    description: Text("No quedan productos con existencias sin contar.")
                )
            }
            ForEach(rows ?? []) { row in
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(row.name)
                        Text("\(row.units) uds · \(ReportFormat.currency(row.value))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    if zeroing.contains(row.productId) {
                        ProgressView()
                    } else {
                        Button("Poner en 0") { Task { await zero([row.productId]) } }
                            .buttonStyle(.bordered)
                            .disabled(!zeroing.isEmpty)
                    }
                }
            }
        }
        .overlay {
            if rows == nil, loadFailed {
                ContentUnavailableView {
                    Label("No se pudo cargar", systemImage: "wifi.exclamationmark")
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                }
            } else if rows == nil {
                ProgressView()
            } else if let zeroProgress {
                ProgressView(zeroProgress)
                    .padding()
                    .background(.regularMaterial, in: .rect(cornerRadius: DS.Radius.l))
            }
        }
        .navigationTitle("No contados")
        .toolbar {
            if let rows, !rows.isEmpty {
                Button("Poner todos en 0") { confirmAll = true }
                    .disabled(!zeroing.isEmpty)
            }
        }
        .confirmationDialog("¿Poner todos en 0?", isPresented: $confirmAll, titleVisibility: .visible) {
            Button("Poner todos en 0", role: .destructive) {
                Task { await zero((rows ?? []).map(\.productId)) }
            }
        } message: {
            Text("\(UncountedSummary(rows ?? []).text). Quedarán en 0 como Conteo inicial; no cuenta como merma.")
        }
        .alert("No contados", isPresented: $showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        do {
            let response: APIResponse<[UncountedProduct]> = try await APIClient.shared.request(
                endpoint: .stockCountUncounted(id: sessionId),
                queryParams: ["locationId": locationId]
            )
            rows = response.data ?? []
            loadFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            loadFailed = true
            self.error = (error as? NetworkError)?.errorDescription ?? "No se pudo cargar la lista"
        }
    }

    private func zero(_ productIds: [String]) async {
        zeroing = Set(productIds)
        defer {
            zeroing = []
            zeroProgress = nil
        }
        var results: [StockCountZeroResult] = []
        var stoppedBy: String?
        for batch in ZeroBatch.split(productIds) {
            if productIds.count > ZeroBatch.size {
                zeroProgress = "Poniendo en 0… \(results.count) de \(productIds.count)"
            }
            do {
                let response: APIResponse<[StockCountZeroResult]> = try await APIClient.shared.request(
                    endpoint: .stockCountZero(id: sessionId),
                    body: StockCountZeroRequest(productIds: batch, locationId: authManager.currentLocation?.id)
                )
                results += response.data ?? []
            } catch {
                stoppedBy = (error as? NetworkError)?.errorDescription ?? "No se pudo poner en 0"
                break
            }
        }
        self.error = ZeroOutcome(results, stoppedBy: stoppedBy).message
        await load()
    }
}
