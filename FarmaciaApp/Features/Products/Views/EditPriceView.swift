import SwiftUI
import FarmaciaKit

// MARK: - Edit Price View
//
// On the form kit (tasks/design-system-epic.md): AmountField, .formKeyboard,
// Guardar → spinner while saving; Guardar's rule is PriceEditing.canSave.

struct EditPriceView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    var onUpdate: ((Product) -> Void)?

    @State private var newPrice: Double?
    @State private var syncToSquare = true
    @State private var applyToAllLocations = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private enum Field: Hashable { case price }
    @FocusState private var focusedField: Field?

    private var canSave: Bool {
        PriceEditing.canSave(newPrice: newPrice, currentPrice: product.sellingPrice)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Precio actual") {
                        Text(product.sellingPrice.map { String(format: "$%.2f MXN", $0) } ?? "Sin precio")
                    }

                    AmountField(
                        "Nuevo precio",
                        prefix: "$",
                        unit: "MXN",
                        value: $newPrice,
                        focus: $focusedField,
                        field: .price
                    )
                }

                if product.hasSquareSync == true {
                    Section {
                        Toggle("Actualizar en Square", isOn: $syncToSquare)

                        if syncToSquare && PriceEditing.canApplyToAllLocations(isOwner: authManager.isOwner) {
                            Toggle("Aplicar a todas las sucursales", isOn: $applyToAllLocations)
                        }
                    } footer: {
                        if syncToSquare {
                            if applyToAllLocations {
                                Text("Se actualiza en Square POS en todas las sucursales de inmediato.")
                            } else {
                                Text("Se actualiza en Square POS solo en esta sucursal.")
                            }
                        } else {
                            Text("Solo se actualiza aquí; Square POS sigue mostrando el precio anterior.")
                        }
                    }
                }

                if canSave, let newPrice {
                    Section("Vista previa") {
                        let change = newPrice - (product.sellingPrice ?? 0)
                        LabeledContent("Cambio de precio") {
                            Text(change >= 0 ? "+\(formatCurrency(change))" : formatCurrency(change))
                                .foregroundStyle((change >= 0 ? Tone.positive : .critical).color)
                        }

                        if let cost = product.averageCost,
                           let margin = Margin.percent(price: newPrice, cost: cost) {
                            LabeledContent("Nuevo margen") {
                                Text(String(format: "%.1f%%", margin))
                                    .foregroundStyle(Margin.tone(forPercent: margin).color)
                            }
                        }
                    }
                }
            }
            // No edits while a save is in flight.
            .disabled(isSubmitting)
            .navigationTitle("Editar Precio")
            .navigationBarTitleDisplayMode(.inline)
            .formKeyboard(focus: $focusedField, order: FocusOrder([.price]))
            // The one thing to type: focus it as the sheet opens.
            .task { focusedField = .price }
            .interactiveDismissDisabled(isSubmitting)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    // While saving, the button becomes a spinner in its place.
                    if isSubmitting {
                        ProgressView()
                            .accessibilityLabel("Guardando")
                    } else {
                        Button("Guardar") {
                            Task {
                                await updatePrice()
                            }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .alert("No se pudo guardar", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func updatePrice() async {
        guard let price = newPrice,
              let locationId = authManager.currentLocation?.id else { return }
        
        isSubmitting = true
        
        do {
            let request = UpdatePriceRequest(
                sellingPrice: price,
                locationId: locationId,
                syncToSquare: syncToSquare,
                applyToAllLocations: syncToSquare ? applyToAllLocations : nil
            )
            
            let response: APIResponse<UpdatePriceResponse> = try await APIClient.shared.request(
                endpoint: .updateProductPrice(id: product.id),
                body: request
            )
            
            let data = try response.requireData()
            onUpdate?(data.product)
            // Write-through: update cache with new price
            ProductCacheManager.shared.saveProduct(data.product)
            
            dismiss()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "No se pudo actualizar el precio"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
