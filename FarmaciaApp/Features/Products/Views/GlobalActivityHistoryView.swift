import SwiftUI

// MARK: - Global Activity History View
// Accessible from the Products toolbar — shows combined receiving and adjustment
// history across ALL products for the current location.

struct GlobalActivityHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = GlobalActivityViewModel()
    @State private var selectedSegment: ActivitySegment = .all
    
    enum ActivitySegment: String, CaseIterable {
        case all = "All"
        case receivings = "Receivings"
        case adjustments = "Adjustments"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segment picker
            Picker("Activity", selection: $selectedSegment) {
                ForEach(ActivitySegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            List {
                switch selectedSegment {
                case .all:
                    allActivitySection
                case .receivings:
                    receivingsSection
                case .adjustments:
                    adjustmentsSection
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadAll(locationId: locationId)
                }
            }
        }
        .navigationTitle("Activity History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let locationId = authManager.currentLocation?.id {
                await viewModel.loadAll(locationId: locationId)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
    
    // MARK: - All Activity
    
    @ViewBuilder
    private var allActivitySection: some View {
        if viewModel.isLoading && viewModel.combinedActivity.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView("Loading activity...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } else if viewModel.combinedActivity.isEmpty {
            Section {
                emptyState(
                    icon: "clock.arrow.circlepath",
                    message: "No activity recorded for this location"
                )
            }
        } else {
            // Group by date
            let grouped = groupByDate(viewModel.combinedActivity)
            ForEach(grouped, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.items) { item in
                        GlobalActivityRow(item: item)
                    }
                }
            }
        }
    }
    
    // MARK: - Receivings Section
    
    @ViewBuilder
    private var receivingsSection: some View {
        if viewModel.isLoadingReceivings && viewModel.receivings.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } else if viewModel.receivings.isEmpty {
            Section {
                emptyState(
                    icon: "shippingbox",
                    message: "No receivings recorded"
                )
            }
        } else {
            Section("Recent Receivings (\(viewModel.receivings.count))") {
                ForEach(viewModel.receivings) { receiving in
                    ReceivingRow(receiving: receiving)
                }
            }
        }
    }
    
    // MARK: - Adjustments Section
    
    @ViewBuilder
    private var adjustmentsSection: some View {
        if viewModel.isLoadingAdjustments && viewModel.adjustments.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } else if viewModel.adjustments.isEmpty {
            Section {
                emptyState(
                    icon: "arrow.triangle.2.circlepath",
                    message: "No adjustments recorded"
                )
            }
        } else {
            Section("Recent Adjustments (\(viewModel.adjustments.count))") {
                ForEach(viewModel.adjustments) { adjustment in
                    AdjustmentRow(adjustment: adjustment)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
    
    private struct DateGroup {
        let key: String
        let items: [GlobalActivityItem]
    }
    
    private func groupByDate(_ items: [GlobalActivityItem]) -> [DateGroup] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        var grouped: [String: [GlobalActivityItem]] = [:]
        var order: [String] = []
        
        for item in items {
            let key = formatter.string(from: item.date)
            if grouped[key] == nil {
                order.append(key)
                grouped[key] = []
            }
            grouped[key]?.append(item)
        }
        
        return order.map { key in
            DateGroup(key: key, items: grouped[key] ?? [])
        }
    }
}

// MARK: - Global Activity Item

struct GlobalActivityItem: Identifiable {
    let id: String
    let productName: String
    let title: String
    let subtitle: String
    let date: Date
    let quantity: Int
    let icon: String
    let iconColor: Color
    
    var quantityDisplay: String {
        if quantity > 0 {
            return "+\(quantity)"
        }
        return "\(quantity)"
    }
    
    var quantityColor: Color {
        quantity > 0 ? .green : .red
    }
}

// MARK: - Global Activity Row

struct GlobalActivityRow: View {
    let item: GlobalActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundColor(item.iconColor)
                .frame(width: 32, height: 32)
                .background(item.iconColor.opacity(0.12))
                .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.productName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(item.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Quantity
            Text(item.quantityDisplay)
                .font(.headline)
                .foregroundColor(item.quantityColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Global Activity ViewModel

@MainActor
class GlobalActivityViewModel: ObservableObject {
    @Published var receivings: [InventoryReceiving] = []
    @Published var adjustments: [InventoryAdjustment] = []
    @Published var isLoading = false
    @Published var isLoadingReceivings = false
    @Published var isLoadingAdjustments = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    private let apiClient = APIClient.shared
    
    var combinedActivity: [GlobalActivityItem] {
        var items: [GlobalActivityItem] = []
        
        for r in receivings {
            items.append(GlobalActivityItem(
                id: "recv-\(r.id)",
                productName: r.product?.displayName ?? "Unknown Product",
                title: "Received \(r.quantity) units",
                subtitle: r.supplier?.name ?? r.invoiceNumber ?? "",
                date: r.receivedAt,
                quantity: r.quantity,
                icon: "arrow.down.circle.fill",
                iconColor: .blue
            ))
        }
        
        for a in adjustments {
            let displayQty = a.type.isNegative ? -abs(a.quantity) : a.quantity
            items.append(GlobalActivityItem(
                id: "adj-\(a.id)",
                productName: a.product?.displayName ?? "Unknown Product",
                title: a.type.displayName,
                subtitle: a.reason ?? a.notes ?? "",
                date: a.adjustedAt,
                quantity: displayQty,
                icon: a.type.icon,
                iconColor: a.type.isPositive ? .green : (a.type.isNegative ? .red : .orange)
            ))
        }
        
        return items.sorted { $0.date > $1.date }
    }
    
    func loadAll(locationId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        async let r: () = loadReceivings(locationId: locationId)
        async let a: () = loadAdjustments(locationId: locationId)
        _ = await (r, a)
    }
    
    private func loadReceivings(locationId: String) async {
        isLoadingReceivings = true
        defer { isLoadingReceivings = false }
        
        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByLocation(locationId: locationId)
            )
            receivings = response.data
        } catch is CancellationError {
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") != true {
                errorMessage = error.errorDescription
                showError = true
            }
        } catch {
            if !error.localizedDescription.lowercased().contains("cancel") {
                errorMessage = "Failed to load receivings"
                showError = true
            }
        }
    }
    
    private func loadAdjustments(locationId: String) async {
        isLoadingAdjustments = true
        defer { isLoadingAdjustments = false }
        
        do {
            let response: AdjustmentListResponse = try await apiClient.request(
                endpoint: .adjustmentsByLocation(locationId: locationId)
            )
            adjustments = response.data
        } catch is CancellationError {
            return
        } catch let error as NetworkError {
            if error.errorDescription?.lowercased().contains("cancel") != true {
                errorMessage = error.errorDescription
                showError = true
            }
        } catch {
            if !error.localizedDescription.lowercased().contains("cancel") {
                errorMessage = "Failed to load adjustments"
                showError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GlobalActivityHistoryView()
            .environmentObject(AuthManager.shared)
    }
}
