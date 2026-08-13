import SwiftUI

// MARK: - Receive Inventory View

struct ReceiveInventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var viewModel: InventoryViewModel
    @State private var showReceiveSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Quick action button
            VStack(spacing: 12) {
                Button {
                    showReceiveSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Recibir Nuevo Inventario")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
            .padding()

            Divider()

            // Recent recepciones - always show List to prevent refresh control issues
            List {
                if viewModel.recentReceivings.isEmpty {
                    Section {
                        if viewModel.isLoadingReceivings {
                            HStack {
                                Spacer()
                                ProgressView("Cargando...")
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                Text("No hay recepciones recientes")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowBackground(Color.clear)
                        }
                    }
                } else {
                    Section("Recepciones Recientes") {
                        ForEach(viewModel.recentReceivings.prefix(10)) { receiving in
                            ReceivingRow(receiving: receiving)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await viewModel.loadProducts()
                if let locationId = authManager.currentLocation?.id {
                    await viewModel.loadReceivings(locationId: locationId)
                }
            }
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView(viewModel: viewModel)
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

// MARK: - Receiving Row

struct ReceivingRow: View {
    let receiving: InventoryReceiving

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(receiving.product?.displayName ?? "Producto Desconocido")
                    .font(.headline)
                Spacer()
                Text("+\(receiving.quantity)")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            HStack {
                if let invoiceNumber = receiving.invoiceNumber {
                    Text("Factura: \(invoiceNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("$\(receiving.unitCost)/unit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(receiving.receivedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Total: $\(receiving.totalCost)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}
