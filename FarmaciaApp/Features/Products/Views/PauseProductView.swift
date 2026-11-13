import SwiftUI
import FarmaciaKit

// MARK: - Pausar
//
// Pauses a product at the session's store (stock alerts O5, owner/manager): it stops
// alerting there and shows as Pausado until someone resumes it or the store receives it.

struct PauseProductView: View {
    let product: Product
    let onPaused: (Product) -> Void

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var reason: PauseReason?
    @State private var replacement: Product?
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: PauseField?

    private var storeName: String { authManager.currentLocation?.name ?? "esta tienda" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(product.displayName) deja de alertar en \(storeName). Se reanuda solo cuando recibas inventario.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section { StatusLabel(errorMessage, tone: .critical) }
                }

                Section("Motivo") {
                    Picker("Motivo", selection: $reason) {
                        ForEach(PauseReason.allCases, id: \.self) { reason in
                            Text(reason.label).tag(Optional(reason))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if reason?.requiresProduct == true {
                    Section("Lo reemplaza") {
                        ProductSearchPicker(selected: $replacement, placeholder: "Nombre, SKU o escanea…",
                                            field: .replacement, focus: $focusedField, scanLabel: "Escanear reemplazo",
                                            subtitle: { $0.sku.map { "SKU \($0)" } ?? "Sin SKU" })
                    }
                }

                Section("Nota (opcional)") {
                    TextField("Ej. el proveedor lo surte en enero", text: $note, axis: .vertical)
                        .formField(.note, focus: $focusedField)
                }
            }
            .navigationTitle("Pausar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Pausar") { Task { await pause() } }
                    }
                }
            }
            .formKeyboard(focus: $focusedField, order: FocusOrder([.replacement, .note]))
            // A form error is about the last try; picking again clears it.
            .onChange(of: reason) { errorMessage = nil }
            .onChange(of: replacement?.id) { errorMessage = nil }
        }
    }

    private func pause() async {
        guard let locationId = authManager.currentLocation?.id else { return }
        switch PauseForm.validate(productId: product.id, locationId: locationId, reason: reason,
                                  replacementId: replacement?.id, note: note) {
        case .fail(let message):
            errorMessage = message
        case .send(let request):
            isSubmitting = true
            defer { isSubmitting = false }
            do {
                let response: ProductDetailResponse = try await APIClient.shared.request(
                    endpoint: .pauseProduct(id: product.id), body: request)
                onPaused(response.data)
                dismiss()
            } catch let error as NetworkError {
                errorMessage = error.errorDescription ?? "No se pudo pausar el producto"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

fileprivate enum PauseField: Hashable { case replacement, note }
