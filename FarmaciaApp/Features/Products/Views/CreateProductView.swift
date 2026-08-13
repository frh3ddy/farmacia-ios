import SwiftUI

// MARK: - Create Product View

struct CreateProductView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: CreateProductViewModel

    // Image picker state
    @State private var selectedImage: UIImage?
    @State private var showImageSourcePicker = false

    // Optional prefilled SKU (e.g. from barcode scanner) — seeded directly
    // into the StateObject at construction time rather than via .onAppear,
    // since .onAppear on a Form inside a freshly-presented sheet doesn't
    // reliably fire in time on the very first presentation, leaving the
    // SKU field blank on the first scan.
    init(prefillSku: String? = nil) {
        _viewModel = StateObject(wrappedValue: CreateProductViewModel(prefillSku: prefillSku))
    }

    var body: some View {
        NavigationStack {
            Form {
                // Product Image Section
                Section {
                    HStack {
                        Spacer()
                        ZStack(alignment: .bottomTrailing) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(.rect(cornerRadius: 16))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 100, height: 100)
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                        Text("Agregar Foto")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Image(systemName: selectedImage != nil ? "pencil.circle.fill" : "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.blue).frame(width: 28, height: 28))
                                .offset(x: 4, y: 4)
                        }
                        .onTapGesture {
                            showImageSourcePicker = true
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Imagen del Producto (Opcional)")
                }
                .confirmationDialog("Agregar Imagen del Producto", isPresented: $showImageSourcePicker) {
                    Button("Tomar Foto") {
                        ImagePickerPresenter.present(sourceType: .camera) { image in
                            selectedImage = image
                        }
                    }
                    Button("Elegir de la Biblioteca") {
                        ImagePickerPresenter.present(sourceType: .photoLibrary) { image in
                            selectedImage = image
                        }
                    }
                    if selectedImage != nil {
                        Button("Eliminar Foto", role: .destructive) {
                            selectedImage = nil
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                }
                
                // Product Info Section
                Section {
                    TextField("Nombre del Producto", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("SKU (Optional)", text: $viewModel.sku)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    
                    TextField("Descripción (Opcional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Información del Producto")
                } footer: {
                    Text("SKU helps identify products quickly. Leave empty to auto-generate.")
                }
                
                // Pricing Section
                Section {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", value: $viewModel.sellingPrice, format: .number)
                            .keyboardType(.decimalPad)
                        Text("MXN")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Precio de Venta")
                } footer: {
                    Text("El precio que los clientes pagarán en caja.")
                }
                
                // Initial Inventory Section (Optional)
                Section {
                    Toggle("Add Initial Stock", isOn: $viewModel.hasInitialStock)
                    
                    if viewModel.hasInitialStock {
                        HStack {
                            Text("Cantidad")
                            Spacer()
                            TextField("0", value: $viewModel.initialStock, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("unidades")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Costo por Unidad")
                            Spacer()
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", value: $viewModel.costPrice, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("MXN")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Inventario Inicial (Opcional)")
                } footer: {
                    if viewModel.hasInitialStock {
                        Text("Esto creará inventario de saldo inicial en la ubicación actual.")
                    } else {
                        Text("Puedes recibir inventario después desde la pestaña de Inventario.")
                    }
                }
                
                // Margin Preview
                if viewModel.showMarginPreview {
                    Section {
                        marginPreviewRow
                    } header: {
                        Text("Vista Previa del Margen")
                    }
                }
                
                // Square Sync Section
                Section {
                    Toggle("Sync to Square POS", isOn: $viewModel.syncToSquare)
                } header: {
                    Text("Square Integration")
                } footer: {
                    if viewModel.syncToSquare {
                        Text("Product will appear in Square POS for sales.")
                    } else {
                        Text("Product will be tracked locally only. Not visible in Square POS.")
                    }
                }
            }
            .navigationTitle("Nuevo Producto")
            .navigationBarTitleDisplayMode(.inline)
            // Breathing room between the keyboard's top edge and bottom
            // fields while editing
            .keyboardTopSpacing(24)
            // Scrolling dismisses the keyboard and removes field focus —
            // otherwise the first tap on the photo area is consumed by the
            // scroll view scrolling back to the focused (off-screen) field
            // instead of opening the image source picker
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Crear") {
                        Task {
                            await createProduct()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    loadingOverlay
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Producto Creado", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }
    
    // MARK: - Margin Preview
    
    private var marginPreviewRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ganancia por Unidad")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let profit = viewModel.profitPerUnit {
                    Text(formatCurrency(profit))
                        .font(.headline)
                        .foregroundStyle(profit >= 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Margen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let margin = viewModel.marginPercent {
                    Text(String(format: "%.1f%%", margin))
                        .font(.headline)
                        .foregroundStyle(margin >= 20 ? .green : (margin >= 10 ? .orange : .red))
                }
            }
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("Creando producto...")
                    .font(.headline)
                
                if selectedImage != nil {
                    Text("Se subirá la imagen después de crear...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.syncToSquare {
                    Text("Syncing to Square...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .clipShape(.rect(cornerRadius: 16))
        }
    }
    
    // MARK: - Actions
    
    private func createProduct() async {
        guard let locationId = authManager.currentLocation?.id else {
            viewModel.errorMessage = "No location selected"
            viewModel.showError = true
            return
        }
        
        await viewModel.createProduct(locationId: locationId, image: selectedImage)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "MXN"
        formatter.locale = Locale(identifier: "es_MX")
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Create Product View Model

@MainActor
class CreateProductViewModel: ObservableObject {
    // Form fields
    @Published var name = ""
    @Published var sku = ""
    @Published var description = ""
    @Published var sellingPrice: Double?
    @Published var costPrice: Double?
    @Published var initialStock: Int?
    @Published var hasInitialStock = false
    @Published var syncToSquare = true
    
    // State
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    
    private let apiClient = APIClient.shared

    init(prefillSku: String? = nil) {
        if let prefillSku, !prefillSku.isEmpty {
            sku = prefillSku
        }
    }

    // MARK: - Computed Properties

    var isValid: Bool {
        // Name is required
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        
        // Selling price is required and must be positive
        guard let price = sellingPrice, price > 0 else { return false }
        
        // If initial stock is enabled, validate stock and cost
        if hasInitialStock {
            guard let stock = initialStock, stock > 0 else { return false }
            guard let cost = costPrice, cost >= 0 else { return false }
        }
        
        return true
    }
    
    var showMarginPreview: Bool {
        hasInitialStock && sellingPrice != nil && costPrice != nil
    }
    
    var profitPerUnit: Double? {
        guard let price = sellingPrice, let cost = costPrice else { return nil }
        return price - cost
    }
    
    var marginPercent: Double? {
        guard let price = sellingPrice, let cost = costPrice, price > 0 else { return nil }
        return ((price - cost) / price) * 100
    }
    
    // MARK: - Actions
    
    func createProduct(locationId: String, image: UIImage? = nil) async {
        isSubmitting = true
        
        do {
            let request = CreateProductRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                sku: sku.isEmpty ? nil : sku.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
                sellingPrice: sellingPrice ?? 0,
                costPrice: hasInitialStock ? costPrice : nil,
                initialStock: hasInitialStock ? initialStock : nil,
                locationId: locationId,
                syncToSquare: syncToSquare
            )
            
            let response: APIResponse<CreateProductResponse> = try await apiClient.request(
                endpoint: .createProduct,
                body: request
            )
            
            if let data = response.data {
                var message = "Producto \"\(name)\" creado exitosamente!"
                if data.squareSynced {
                    message += "\n✓ Synced to Square POS"
                }
                if data.inventoryCreated {
                    message += "\n✓ Initial inventory added"
                }
                
                // Upload image if one was selected (resized to 1600px ceiling first)
                if let image = image, let imageData = image.jpegDataForUpload() {
                    do {
                        let _: ImageUploadResponse = try await apiClient.uploadImage(
                            endpoint: .uploadProductImage(id: data.product.id),
                            imageData: imageData,
                            filename: "product_\(data.product.id).jpg"
                        )
                        message += "\n✓ Product image uploaded"
                    } catch {
                        message += "\n⚠ Image upload failed (product was created)"
                        print("Failed to upload product image: \(error)")
                    }
                }
                
                successMessage = message
                showSuccess = true
            }
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "Error al crear producto"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isSubmitting = false
    }
}

// MARK: - Preview

#Preview {
    CreateProductView()
        .environmentObject(AuthManager.shared)
}
