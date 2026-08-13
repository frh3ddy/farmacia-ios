import SwiftUI

// MARK: - Adjustments List View

struct AdjustmentsListView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showAdjustmentSheet = false
    @State private var selectedAdjustmentType: AdjustmentType = .damage

    private let adjustmentTypes: [AdjustmentType] = [.damage, .theft, .expired, .found, .returnType, .countCorrection]

    var body: some View {
        VStack(spacing: 0) {
            // Quick adjustment buttons - horizontal only, no pull to refresh
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(adjustmentTypes, id: \.self) { type in
                        Button {
                            selectedAdjustmentType = type
                            showAdjustmentSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 70)
                            .background(Color(.systemGray6))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 90)
            .padding(.vertical, 8)

            Divider()

            // Recent ajustes - always show List to prevent refresh control issues
            List {
                if viewModel.recentAdjustments.isEmpty {
                    Section {
                        if viewModel.isLoadingAdjustments {
                            HStack {
                                Spacer()
                                ProgressView("Cargando...")
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                Text("No hay ajustes recientes")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowBackground(Color.clear)
                        }
                    }
                } else {
                    Section("Ajustes Recientes") {
                        ForEach(viewModel.recentAdjustments.prefix(10)) { adjustment in
                            AdjustmentRow(adjustment: adjustment)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await viewModel.loadProducts()
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadAdjustments(locationId: locationId)
                }
            }
        }
        .sheet(isPresented: $showAdjustmentSheet) {
            AdjustmentFormView(adjustmentType: selectedAdjustmentType, viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "Ocurrió un error")
        }
        .alert("Éxito", isPresented: $viewModel.showSuccess) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage ?? "Operación completada")
        }
    }
}

// MARK: - Adjustment Row

struct AdjustmentRow: View {
    let adjustment: InventoryAdjustment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: adjustment.type.icon)
                    .foregroundStyle(typeColor)

                Text(adjustment.product?.displayName ?? "Producto Desconocido")
                    .font(.headline)

                Spacer()

                Text(adjustment.quantityDisplay)
                    .font(.headline)
                    .foregroundStyle(typeColor)
            }

            HStack {
                Text(adjustment.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(.rect(cornerRadius: 4))

                if let reason = adjustment.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(adjustment.adjustedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        if adjustment.type.isPositive {
            return .green
        } else if adjustment.type.isNegative {
            return .red
        }
        return .orange
    }
}
