import SwiftUI

// MARK: - Supplier Picker View

struct SupplierPickerView: View {
    @Binding var suppliers: [Supplier]
    @Binding var selectedSupplier: Supplier?

    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showCreateSupplier = false
    @State private var newSupplierName = ""
    @State private var isCreating = false
    @State private var createError: String?

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
                        Button("Agregar Proveedor") {
                            newSupplierName = searchText
                            showCreateSupplier = true
                        }
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
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Buscar proveedores")
                }
            }
            .navigationTitle("Seleccionar Proveedor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newSupplierName = searchText
                        showCreateSupplier = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Nuevo Proveedor", isPresented: $showCreateSupplier) {
                TextField("Nombre del proveedor", text: $newSupplierName)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") {
                    Task { await createSupplier() }
                }
            }
            .alert("Error", isPresented: .constant(createError != nil)) {
                Button("OK") { createError = nil }
            } message: {
                Text(createError ?? "")
            }
            .disabled(isCreating)
        }
    }

    private func createSupplier() async {
        let name = newSupplierName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isCreating = true
        defer { isCreating = false }

        do {
            let response: CreateSupplierResponse = try await APIClient.shared.request(
                endpoint: .createSupplier,
                body: CreateSupplierRequest(name: name)
            )
            if let index = suppliers.firstIndex(where: { $0.id == response.supplier.id }) {
                suppliers[index] = response.supplier
            } else {
                suppliers.append(response.supplier)
            }
            selectedSupplier = response.supplier
            dismiss()
        } catch let error as NetworkError {
            createError = error.errorDescription ?? "No se pudo crear el proveedor"
        } catch {
            createError = error.localizedDescription
        }
    }
}
