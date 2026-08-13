import SwiftUI

// MARK: - Product Picker View

struct ProductPickerView: View {
    let products: [Product]
    @Binding var selectedProduct: Product?
    let isLoading: Bool

    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var filteredProducts: [Product] {
        if searchText.isEmpty {
            return products
        }
        let lowercased = searchText.lowercased()
        return products.filter { product in
            product.displayName.lowercased().contains(lowercased) ||
            product.sku?.lowercased().contains(lowercased) == true ||
            product.name.lowercased().contains(lowercased)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Cargando productos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if products.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cube.box")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No se encontraron productos")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredProducts) { product in
                            Button {
                                selectedProduct = product
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.displayName)
                                            .foregroundStyle(.primary)

                                        HStack(spacing: 8) {
                                            if let sku = product.sku {
                                                Text("SKU: \(sku)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            if let category = product.category {
                                                Text(category.name)
                                                    .font(.caption)
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }

                                    Spacer()

                                    if selectedProduct?.id == product.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Buscar productos")
                }
            }
            .navigationTitle("Seleccionar Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
