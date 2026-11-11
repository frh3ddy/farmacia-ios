import SwiftUI
import FarmaciaKit

// MARK: - Busy Hours (tasks/sales-intel-epic.md)
//
// Orders per weekday × hour at the current store, from Square sales history.
// Owner/manager only (the API refuses the rest). Shown on Inicio (last 90 days)
// and in Reportes (with a period picker).

/// The heat grid: one row per day (Monday first), one column per hour with orders.
/// Opacity by share of the busiest slot, plus the top-3 text so it isn't color alone.
struct BusyHoursGrid: View {
    let busy: BusyHours
    let timezone: String

    var body: some View {
        if busy.isEmpty {
            EmptyRow(text: busy.topText, systemImage: "clock")
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.s) {
                Label(busy.topText, systemImage: "flame")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        ForEach(busy.hours, id: \.self) { hour in
                            Text(hour % 3 == 0 ? "\(hour)" : "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
                    ForEach(busy.days, id: \.dayOfWeek) { day in
                        GridRow {
                            Text(day.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .gridColumnAlignment(.leading)
                            ForEach(busy.hours, id: \.self) { hour in
                                let share = busy.share(day: day.dayOfWeek, hour: hour)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(share > 0 ? Color.accentColor.opacity(0.12 + 0.88 * share) : Color(.systemGray6))
                                    .frame(height: 18)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Horas pico: \(busy.topText)")

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Pedidos por hora · hora del centro de México".
    private var caption: String {
        let zone = TimeZone(identifier: timezone)?.localizedName(for: .generic, locale: DisplayDate.locale) ?? timezone
        return "Pedidos por hora · \(zone)"
    }
}

/// Loads busy hours for the current store; nil while loading, hidden on failure.
@MainActor @Observable
final class BusyHoursLoader {
    private(set) var response: BusyHours.Response?
    private(set) var isLoaded = false

    func load(locationId: String?, days: Int) async {
        guard let locationId else { return }
        isLoaded = false
        response = nil // never show another store's or period's grid while loading
        let fresh = await APIClient.shared.busyHours(locationId: locationId, days: days)
        // A store/period switch cancelled this load; the newer one owns the state.
        guard !Task.isCancelled else { return }
        response = fresh
        isLoaded = true
    }
}

/// Inicio: last 90 days at the current store.
struct BusyHoursCard: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var loader = BusyHoursLoader()

    var body: some View {
        Group {
            if let response = loader.response {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Horas pico · 90 días", systemImage: "clock.fill")
                        .font(.headline)
                    BusyHoursGrid(busy: BusyHours(cells: response.cells), timezone: response.timezone)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(.rect(cornerRadius: 12))
                }
            } else if !loader.isLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .task(id: authManager.currentLocation?.id) {
            await loader.load(locationId: authManager.currentLocation?.id, days: 90)
        }
    }
}

/// Reportes: the same grid over a chosen period.
struct BusyHoursReportView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var loader = BusyHoursLoader()
    @State private var days = 90

    var body: some View {
        List {
            Section {
                Picker("Período", selection: $days) {
                    Text("30 días").tag(30)
                    Text("90 días").tag(90)
                    Text("1 año").tag(365)
                    Text("2 años").tag(730)
                }
                .pickerStyle(.segmented)
            }
            Section(authManager.currentLocation?.name ?? "") {
                if let response = loader.response {
                    BusyHoursGrid(busy: BusyHours(cells: response.cells), timezone: response.timezone)
                } else if loader.isLoaded {
                    EmptyRow(text: "No se pudieron cargar las horas pico", systemImage: "wifi.exclamationmark")
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Horas pico")
        .task(id: "\(authManager.currentLocation?.id ?? "")-\(days)") {
            await loader.load(locationId: authManager.currentLocation?.id, days: days)
        }
        .refreshable {
            await loader.load(locationId: authManager.currentLocation?.id, days: days)
        }
    }
}
