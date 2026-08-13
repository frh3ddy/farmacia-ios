import SwiftUI

// MARK: - Stock Alert Products View (linked from Dashboard)

struct StockAlertProductsView: View {
    let products: [Product]
    @State private var selectedFilter: AlertFilter = .outOfStock
    
    enum AlertFilter: String, CaseIterable {
        case outOfStock = "Sin Stock"
        case lowStock = "Stock Bajo"
        case lowMargin = "Margen Bajo"
    }
    
    private var filteredProducts: [Product] {
        switch selectedFilter {
        case .outOfStock:
            return products.filter { ($0.totalInventory ?? 0) == 0 }
        case .lowStock:
            return products.filter { ($0.totalInventory ?? 0) > 0 && ($0.totalInventory ?? 0) < 10 }
        case .lowMargin:
            return products.filter { ($0.profitMargin ?? 100) < 10 }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Filtrar", selection: $selectedFilter) {
                ForEach(AlertFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                if filteredProducts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("No hay productos en esta categoría")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRow(product: product)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Alertas de Inventario")
        .navigationBarTitleDisplayMode(.inline)
    }
}

