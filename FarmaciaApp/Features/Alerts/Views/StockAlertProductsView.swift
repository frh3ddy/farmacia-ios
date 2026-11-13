import SwiftUI
import FarmaciaKit

// MARK: - Stock Alert Products View (Alertas → Ver Productos)

/// Alertas' ranked lists (stock alerts O6): the products losing the most sales a day
/// first, each with its reason, paged from the server (no 200 cap).
struct StockAlertProductsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = AlertListViewModel()
    @State private var selected: AlertList = .out

    private var locationId: String? { authManager.currentLocation?.id }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Filtrar", selection: $selected) {
                ForEach(AlertList.visible(canViewCosts: authManager.canViewCosts), id: \.self) { list in
                    Text(list.rawValue).tag(list)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            if let note = selected.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, DS.Spacing.xs)
            }

            List {
                if let message = viewModel.errorMessage {
                    StatusLabel(message, tone: .critical)
                }
                if viewModel.rows.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                    ContentUnavailableView("No hay productos en esta categoría", systemImage: "checkmark.circle")
                        .listRowBackground(Color.clear)
                }
                ForEach(viewModel.rows) { product in
                    NavigationLink {
                        ProductDetailView(product: product) { viewModel.update($0) }
                    } label: {
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            ProductRow(product: product, showsMargin: authManager.canViewCosts)
                            if let reason = product.stockAlert?.reasonText(quantity: product.totalInventory ?? 0) {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .task { await viewModel.loadMore(after: product) }
                }
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                guard let locationId else { return }
                await viewModel.show(selected, locationId: locationId, force: true)
            }
        }
        .navigationTitle("Alertas de Inventario")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selected) {
            guard let locationId else { return }
            await viewModel.show(selected, locationId: locationId)
        }
    }
}
