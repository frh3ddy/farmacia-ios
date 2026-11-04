import SwiftUI
import FarmaciaKit

// MARK: - Supplier Picker View

/// Pushed from a form's Proveedor row (not a sheet): choosing a value inside a
/// form is a push, like Settings, so it can't race the form's own animations.
/// Picking or creating a supplier pops back.
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
        Group {
            if suppliers.isEmpty {
                ContentUnavailableView {
                    Label("Sin proveedores", systemImage: "building.2")
                } description: {
                    Text("Agrega el primero para asignarlo a este producto.")
                } actions: {
                    Button("Agregar proveedor") {
                        newSupplierName = searchText
                        showCreateSupplier = true
                    }
                }
            } else {
                List {
                    // A normal choice, not a clear button next to the chevron.
                    if searchText.isEmpty {
                        Button {
                            selectedSupplier = nil
                            dismiss()
                        } label: {
                            HStack {
                                Text("Sin proveedor")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSupplier == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedSupplier == nil ? .isSelected : [])
                    }

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
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedSupplier?.id == supplier.id ? .isSelected : [])
                    }
                }
                .searchable(text: $searchText, prompt: "Buscar proveedores")
            }
        }
        .navigationTitle("Seleccionar Proveedor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
