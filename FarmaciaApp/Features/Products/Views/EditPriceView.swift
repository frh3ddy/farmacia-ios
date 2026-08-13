import SwiftUI

// MARK: - Edit Price View

struct EditPriceView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    let product: Product
    var onUpdate: ((Product) -> Void)?
    
    @State private var priceText: String = ""
    @State private var syncToSquare = true
    @State private var applyToAllLocations = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var newPrice: Double? {
        Double(priceText.replacingOccurrences(of: ",", with: "."))
    }
    
    private var isValid: Bool {
        guard let price = newPrice, price > 0 else { return false }
        return true
    }
    
    private var priceChanged: Bool {
        guard let newPrice = newPrice else { return false }
        return newPrice != product.sellingPrice
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Precio Actual")
                        Spacer()
                        Text(product.formattedPrice ?? "No definido")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("Nuevo Precio", text: $priceText)
                            .keyboardType(.decimalPad)
                        Text("MXN")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Precio de Venta")
                }
                
                if product.hasSquareSync == true {
                    Section {
                        Toggle("Actualizar en Square", isOn: $syncToSquare)
                        
                        if syncToSquare {
                            Toggle("Aplicar a todas las ubicaciones", isOn: $applyToAllLocations)
                        }
                    } footer: {
                        if syncToSquare {
                            if applyToAllLocations {
                                Text("El precio se actualizará en Square POS en TODAS las ubicaciones inmediatamente.")
                            } else {
                                Text("El precio se actualizará en Square POS solo para la ubicación actual.")
                            }
                        } else {
                            Text("El precio solo se actualizará localmente. Square POS mostrará el precio anterior.")
                        }
                    }
                }
                
                // Preview
                if let newPrice = newPrice, priceChanged {
                    Section {
                        HStack {
                            Text("Cambio de Precio")
                            Spacer()
                            let change = newPrice - (product.sellingPrice ?? 0)
                            Text(change >= 0 ? "+\(formatCurrency(change))" : formatCurrency(change))
                                .foregroundStyle(change >= 0 ? .green : .red)
                        }
                        
                        if let cost = product.averageCost {
                            let newMargin = ((newPrice - cost) / newPrice) * 100
                            HStack {
                                Text("Nuevo Margen")
                                Spacer()
                                Text(String(format: "%.1f%%", newMargin))
                                    .foregroundStyle(newMargin >= 20 ? .green : (newMargin >= 10 ? .orange : .red))
                            }
                        }
                    } header: {
                        Text("Vista Previa")
                    }
                }
            }
            .navigationTitle("Editar Precio")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardTopSpacing(24)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        Task {
                            await updatePrice()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || !priceChanged || isSubmitting)
                }
            }
            .onAppear {
                if let price = product.sellingPrice {
                    priceText = String(format: "%.2f", price)
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .alert("Error", isPresented: $showError) {
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
            
            if let data = response.data {
                onUpdate?(data.product)
                // Write-through: update cache with new price
                ProductCacheManager.shared.saveProduct(data.product)
            }
            
            dismiss()
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Failed to update price"
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
