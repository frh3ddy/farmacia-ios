import SwiftUI

// MARK: - Alerts View
// Hosts all stock/inventory warnings (low stock, expiring products, actionable
// signals) so the Dashboard tab can stay focused on sales and FIFO reporting.

struct AlertsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var stockAlertViewModel = StockAlertViewModel()
    @StateObject private var signalsViewModel = ActionableSignalsViewModel()
    @StateObject private var expiringViewModel = DashboardExpiringViewModel()
    // Create Shopping List action — disabled for now, not fully ready.
    // @State private var showShoppingListCreated = false
    // @State private var createdListName = ""
    //
    // private var shoppingListStore: ShoppingListStore { ShoppingListStore.shared }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: 20) {
                    if stockAlertViewModel.needsAttention {
                        stockAlertCard
                    }

                    if expiringViewModel.hasExpiringProducts {
                        expiringAlertCard
                    }

                    if !signalsViewModel.signals.isEmpty {
                        actionableSignalsSection
                    }

                    if !stockAlertViewModel.needsAttention
                        && !expiringViewModel.hasExpiringProducts
                        && signalsViewModel.signals.isEmpty
                        && !stockAlertViewModel.isLoading {
                        emptyStateSection
                    }
                }
                .padding()
                .containerRelativeFrame(.horizontal)
            }
            .refreshable {
                await loadAll()
            }
            .navigationTitle("Alertas")
            .task {
                await loadAll()
            }
        }
    }

    private func loadAll() async {
        async let alertsLoad: () = loadStockAlerts()
        async let signalsLoad: () = loadSignals()
        async let expiringLoad: () = loadExpiringData()
        _ = await (alertsLoad, signalsLoad, expiringLoad)
    }

    private func loadStockAlerts() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await stockAlertViewModel.loadProducts(locationId: locationId)
    }

    private func loadSignals() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await signalsViewModel.loadSignals(locationId: locationId)
    }

    private func loadExpiringData() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        await expiringViewModel.loadExpiring(locationId: locationId)
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)

            Text("Todo en orden")
                .font(.headline)

            Text("No hay alertas de inventario en este momento.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    // MARK: - Stock Alert Card

    private var stockAlertCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)

                Text("Alertas de Inventario")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    // Navigate to Products tab (via MainTabView)
                    // For now, link to a filtered products view
                    StockAlertProductsView(products: stockAlertViewModel.products)
                } label: {
                    Text("Ver Productos")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }

            Divider()

            HStack(spacing: 16) {
                if stockAlertViewModel.outOfStockCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.outOfStockCount)",
                        label: "Sin Stock",
                        color: .red
                    )
                }

                if stockAlertViewModel.lowStockCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.lowStockCount)",
                        label: "Stock Bajo",
                        color: .orange
                    )
                }

                if stockAlertViewModel.lowMarginCount > 0 {
                    alertMetric(
                        value: "\(stockAlertViewModel.lowMarginCount)",
                        label: "Margen Bajo",
                        color: .purple
                    )
                }

                Spacer()
            }

            // Create Shopping List action — disabled for now, not fully ready.
            // Divider()
            //
            // Button {
            //     createRestockShoppingList()
            // } label: {
            //     HStack {
            //         Image(systemName: "list.clipboard")
            //         Text("Crear Lista de Reabasto")
            //         Spacer()
            //         Text("\(stockAlertViewModel.outOfStockCount + stockAlertViewModel.lowStockCount) artículos")
            //             .foregroundStyle(.secondary)
            //         Image(systemName: "chevron.right")
            //             .font(.caption2)
            //             .foregroundStyle(.secondary)
            //     }
            //     .font(.caption)
            //     .fontWeight(.medium)
            //     .foregroundStyle(.blue)
            // }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        // .alert("Lista de Compras Creada", isPresented: $showShoppingListCreated) {
        //     Button("OK") {}
        // } message: {
        //     Text("\"\(createdListName)\" ha sido creada con artículos que necesitan reabasto. Abre Listas de Compras desde la pestaña de Productos para revisar.")
        // }
    }

    private func alertMetric(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }

    // MARK: - Expiring Products Alert Card

    private var expiringAlertCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .font(.title3)

                Text("Productos por Vencer")
                    .font(.headline)

                Spacer()

                if let summary = expiringViewModel.summary {
                    Text("$\(String(format: "%.0f", summary.totalCashAtRisk)) en riesgo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(.rect(cornerRadius: 6))
                }
            }

            Divider()

            if let summary = expiringViewModel.summary {
                HStack(spacing: 16) {
                    if summary.totalExpiredBatches > 0 {
                        alertMetric(
                            value: "\(summary.totalExpiredBatches)",
                            label: "Vencidos",
                            color: .red
                        )
                    }
                    if summary.criticalCount > 0 {
                        alertMetric(
                            value: "\(summary.criticalCount)",
                            label: "Crítico",
                            color: .red
                        )
                    }
                    if summary.highCount > 0 {
                        alertMetric(
                            value: "\(summary.highCount)",
                            label: "Por Vencer",
                            color: .orange
                        )
                    }
                    alertMetric(
                        value: "\(summary.totalProducts)",
                        label: "Productos",
                        color: .secondary
                    )
                    Spacer()
                }
            }

            // Top 3 expiring products
            ForEach(expiringViewModel.products.prefix(3)) { product in
                HStack(spacing: 8) {
                    Image(systemName: product.severityIcon)
                        .font(.caption)
                        .foregroundStyle(product.severityColor)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(product.productName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("\(product.totalUnits) unidades")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if product.expiredCount > 0 {
                                Text("\u{2022} \(product.expiredCount) vencidos")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            } else {
                                Text("\u{2022} vence \(product.soonestExpiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    Spacer()

                    Text(product.formattedCashAtRisk)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Actionable Signals Section

    private var actionableSignalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.title3)

                Text("Acción Requerida")
                    .font(.headline)

                Spacer()

                if signalsViewModel.signals.count > 3 {
                    NavigationLink {
                        AllSignalsView(signals: signalsViewModel.signals)
                    } label: {
                        Text("Ver Todos (\(signalsViewModel.signals.count))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
            }

            Divider()

            // Show up to 3 signals
            ForEach(signalsViewModel.signals.prefix(3)) { signal in
                signalRow(signal)

                if signal.id != signalsViewModel.signals.prefix(3).last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func signalRow(_ signal: ActionableSignal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Signal type icon
                Image(systemName: signal.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(signal.severity.color)
                    .frame(width: 28, height: 28)
                    .background(signal.severity.color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.entityName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(signal.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Severity + cash badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(signal.severity.displayName)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signal.severity.color.opacity(0.15))
                        .foregroundStyle(signal.severity.color)
                        .clipShape(.rect(cornerRadius: 4))

                    if let cash = signal.formattedCashAtRisk {
                        Text(cash)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Recommended actions (compact)
            if !signal.recommendedActions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(signal.recommendedActions.prefix(2), id: \.self) { action in
                        Text(action)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.secondary)
                            .clipShape(.rect(cornerRadius: 4))
                    }

                    if signal.recommendedActions.count > 2 {
                        Text("+\(signal.recommendedActions.count - 2)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Shopping List Creation Helpers — disabled for now, not fully ready.

    // private func createRestockShoppingList() {
    //     let outOfStock = stockAlertViewModel.products.filter { ($0.totalInventory ?? 0) == 0 }
    //     let lowStock = stockAlertViewModel.products.filter {
    //         let inv = $0.totalInventory ?? 0
    //         return inv > 0 && inv < 10
    //     }
    //
    //     let dateSuffix = Date().formatted(date: .abbreviated, time: .omitted)
    //     let name = "Reabasto \(dateSuffix)"
    //
    //     var list = ShoppingList(
    //         name: name,
    //         locationId: authManager.currentLocation?.id,
    //         locationName: authManager.currentLocation?.name
    //     )
    //
    //     for product in outOfStock {
    //         let reorderTarget = 10
    //         let item = ShoppingListItem(
    //             productId: product.id,
    //             productName: product.displayName,
    //             sku: product.sku,
    //             plannedQuantity: reorderTarget,
    //             unitCost: product.averageCost ?? 0,
    //             previousCost: product.averageCost
    //         )
    //         list.addItem(item)
    //     }
    //     for product in lowStock {
    //         let stock = product.totalInventory ?? 0
    //         let reorderTarget = 10
    //         let suggestedQty = max(1, reorderTarget - stock)
    //         let item = ShoppingListItem(
    //             productId: product.id,
    //             productName: product.displayName,
    //             sku: product.sku,
    //             plannedQuantity: suggestedQty,
    //             unitCost: product.averageCost ?? 0,
    //             previousCost: product.averageCost
    //         )
    //         list.addItem(item)
    //     }
    //
    //     shoppingListStore.save(list)
    //     createdListName = name
    //     showShoppingListCreated = true
    // }
}

// MARK: - Preview

#Preview {
    AlertsView()
        .environmentObject(AuthManager.shared)
}
