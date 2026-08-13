import SwiftUI

// MARK: - Supplier Picker View

struct SupplierPickerView: View {
    let suppliers: [Supplier]
    @Binding var selectedSupplier: Supplier?

    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""

    private var filteredSuppliers: [Supplier] {
        if searchText.isEmpty {
            return suppliers
        }
        let lowercased = searchText.lowercased()
        return suppliers.filter { supplier in
            supplier.name.lowercased().contains(lowercased)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if suppliers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No se encontraron proveedores")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSuppliers) { supplier in
                            Button {
                                selectedSupplier = supplier
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(supplier.name)
                                            .foregroundStyle(.primary)

                                        if let contactInfo = supplier.contactInfo {
                                            Text(contactInfo)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if selectedSupplier?.id == supplier.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Buscar proveedores")
                }
            }
            .navigationTitle("Seleccionar Proveedor")
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
