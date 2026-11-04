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
    /// The owner's "every store" switch: on unless turned off (tasks/price-all-locations-epic.md).
    @State private var everyStore = true
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private enum Field: Hashable { case price }
    @FocusState private var focusedField: Field?

    /// Owner, and a product sold at more than one store: the switch shows, starting on.
    private var canChooseStores: Bool {
        PriceEditing.appliesToAllLocations(isOwner: authManager.isOwner,
                                           soldOnlyAtLocationId: product.soldOnlyAtLocationId)
    }

    private var applyToAllLocations: Bool { canChooseStores && everyStore }

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
                } footer: {
                    Text(PriceEditing.scopeNote(allLocations: applyToAllLocations, syncToSquare: syncToSquare,
                                                storeName: authManager.currentLocation?.name ?? "esta sucursal",
                                                isOwner: authManager.isOwner))
                }

                if canChooseStores || product.hasSquareSync == true {
                    Section {
                        if canChooseStores {
                            Toggle("Aplicar en todas las sucursales", isOn: $everyStore)
                        }
                        if product.hasSquareSync == true {
                            Toggle("Actualizar en Square", isOn: $syncToSquare)
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
                applyToAllLocations: applyToAllLocations
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
