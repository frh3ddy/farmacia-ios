import SwiftUI
import FarmaciaKit

// MARK: - Product Inventory Card
// Stock here, its alert or pause, and the other stores' stock.

struct ProductInventoryCard<Activity: View>: View {
    let product: Product
    let locationName: String?
    let currentLocationId: String?
    let storeStock: [StoreStock]
    let storeStockLoaded: Bool
    /// Stores this employee can see: how many placeholder rows to show while loading.
    let knownLocations: Int
    /// Where "Movimientos" leads.
    @ViewBuilder let activity: () -> Activity

    private var expectsStoreStock: Bool {
        StoreStock.isExpected(tracksInventory: product.tracksInventory,
                              soldOnlyAtLocationId: product.soldOnlyAtLocationId)
    }

    var body: some View {
        inventoryCard
    }

    private var inventoryCard: some View {
        let here = product.totalInventory ?? 0
        return VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack {
                Label("Inventario", systemImage: "shippingbox")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    activity()
                } label: {
                    HStack(spacing: DS.Spacing.xxs) {
                        Text("Movimientos")
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .frame(minHeight: DS.minTapSize)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text("\(here)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("uds en esta tienda")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let name = locationName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            let level = StockLevel(quantity: here, alert: product.stockAlert)
            let isPaused = product.stockAlert?.paused == true
            if let text = level.detailText {
                StatusLabel(text, tone: level.tone, systemImage: isPaused ? "pause.circle" : nil)
                    .font(.caption)
                    .fontWeight(.medium)
                if isPaused {
                    Text("Se reanuda solo cuando recibas inventario.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // The alerts' own rate (StockAlert.salesLine), so it matches Alertas' reason.
            if let sales = product.stockAlert?.salesLine() {
                Label(sales, systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            otherStoresRows
        }
        .card()
    }

    /// The other stores' stock (tasks/other-stores-stock-epic.md). Hidden when
    /// there's none to show: offline, failed fetch, untracked, or sold only here.
    /// A store without it is a neutral "0 uds", not an alarm.
    @ViewBuilder
    private var otherStoresRows: some View {
        let stores = StoreStock.others(storeStock, currentLocationId: currentLocationId)
        if !storeStockLoaded && expectsStoreStock {
            Divider()
            // First load: placeholder rows, so the block visibly fills in.
            ForEach(0..<StoreStock.placeholderRows(knownLocations: knownLocations), id: \.self) { _ in
                LabeledContent("Sucursal") { Text("00 uds") }
                    .font(.subheadline)
            }
            .redacted(reason: .placeholder)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cargando existencias")
        } else if !stores.isEmpty {
            Divider()
            let here = product.totalInventory ?? 0
            ForEach(stores) { store in
                let standsOut = store.standsOut(hereQuantity: here)
                LabeledContent {
                    Text("\(store.quantity) uds")
                        .monospacedDigit()
                        .fontWeight(standsOut ? .bold : .regular)
                        .foregroundStyle(standsOut ? Tone.positive.color : (store.quantity > 0 ? .primary : .secondary))
                } label: {
                    Label(store.locationName, systemImage: "building.2")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }
}
