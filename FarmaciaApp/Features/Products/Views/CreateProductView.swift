import SwiftUI
import FarmaciaKit
import SwiftyCrop

// MARK: - Create Product View
//
// Design-system pilot (tasks/design-system-epic.md): DS tokens, AmountField,
// Margin/Tone, .formKeyboard. Presentation rules:
//   - Everything full-screen in the photo flow is one destination
//     (`photoDestination`) on one `fullScreenCover(item:)`. Moving between steps
//     swaps the item; SwiftUI replaces the content, so nothing races.
//   - The photo source is a `Menu` (no dialog to animate away before the camera
//     or library can open).
//   - The supplier is chosen by a push, not a sheet.

/// Every full-screen step of the photo flow.
private enum PhotoDestination: Identifiable {
    case camera
    case library
    case crop(UIImage)
    case preview

    var id: String {
        switch self {
        case .camera: "camera"
        case .library: "library"
        case .crop: "crop"
        case .preview: "preview"
        }
    }
}

struct CreateProductView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: CreateProductViewModel

    // Photo state
    @State private var selectedImage: UIImage?
    @State private var originalCroppedImage: UIImage?
    @State private var liftedImage: UIImage?
    @State private var backgroundRemoved = true
    @State private var isLiftingSubject = false
    @State private var photoDestination: PhotoDestination?
    /// Where Retomar Foto goes: the source the current photo came from.
    @State private var photoSource: PhotoDestination = .library
    @State private var showDiscardConfirmation = false

    /// Anything entered (photo included): the sheet can't be swiped away and
    /// Cancelar asks before discarding it.
    private var hasUnsavedChanges: Bool {
        viewModel.hasChanges(hasPhoto: selectedImage != nil)
    }

    private enum Field: Hashable {
        case name, sku, description, sellingPrice, quantity, unitCost
    }
    @FocusState private var focusedField: Field?

    private var focusOrder: FocusOrder<Field> {
        FocusOrder([.name, .sku, .description, .sellingPrice]
            + (viewModel.hasInitialStock ? [.quantity, .unitCost] : []))
    }

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
                photoSection

                // Product Info Section
                Section {
                    TextField("Nombre del Producto", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                        .formField(.name, focus: $focusedField)

                    TextField("SKU (Optional)", text: $viewModel.sku)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .formField(.sku, focus: $focusedField)

                    TextField("Descripción (Opcional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...4)
                        .formField(.description, focus: $focusedField)
                } header: {
                    Text("Información del Producto")
                } footer: {
                    Text("SKU helps identify products quickly. Leave empty to auto-generate.")
                }

                // Pricing Section
                Section {
                    AmountField(
                        prefix: "$",
                        unit: "MXN",
                        value: $viewModel.sellingPrice,
                        focus: $focusedField,
                        field: .sellingPrice
                    )
                } header: {
                    Text("Precio de Venta")
                } footer: {
                    Text("El precio que los clientes pagarán en caja.")
                }

                // Initial Inventory Section (Optional)
                Section {
                    Toggle("Add Initial Stock", isOn: $viewModel.hasInitialStock)

                    if viewModel.hasInitialStock {
                        AmountField(
                            "Cantidad",
                            unit: "UDS",
                            quantity: $viewModel.initialStock,
                            focus: $focusedField,
                            field: .quantity
                        )

                        AmountField(
                            "Costo por Unidad",
                            unit: "MXN",
                            value: $viewModel.costPrice,
                            focus: $focusedField,
                            field: .unitCost
                        )

                        NavigationLink {
                            SupplierPickerView(
                                suppliers: $viewModel.suppliers,
                                selectedSupplier: $viewModel.selectedSupplier
                            )
                        } label: {
                            LabeledContent("Proveedor", value: viewModel.selectedSupplier?.name ?? "Seleccionar (Opcional)")
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

                // Stores Section
                Section {
                    Toggle("Vender en todas las sucursales", isOn: $viewModel.soldAtAllLocations)
                } header: {
                    Text("Sucursales")
                } footer: {
                    if !viewModel.soldAtAllLocations {
                        Text("Solo se venderá en esta sucursal y no aparecerá en las demás.")
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
            .formKeyboard(focus: $focusedField, order: focusOrder)
            // Swiping the sheet down would lose what's been entered.
            .interactiveDismissDisabled(hasUnsavedChanges)
            .fullScreenCover(item: $photoDestination) { destination in
                photoScreen(for: destination)
            }
            .onChange(of: backgroundRemoved) { _, removed in
                guard let originalCroppedImage else { return }
                selectedImage = removed ? (liftedImage ?? originalCroppedImage) : originalCroppedImage
            }
            .task {
                await viewModel.loadSuppliers()
            }
            .navigationTitle("Nuevo Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        if hasUnsavedChanges {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .confirmationDialog(
                        "¿Descartar producto?",
                        isPresented: $showDiscardConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Descartar", role: .destructive) { dismiss() }
                        Button("Seguir editando", role: .cancel) {}
                    } message: {
                        Text("Se perderá la información que ingresaste.")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        Task {
                            await createProduct()
                        }
                    }
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
            .alert(
                viewModel.successMessage.hasPrefix("Sin conexión") ? "Sin conexión" : "Producto Creado",
                isPresented: $viewModel.showSuccess
            ) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage)
            }
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    if let image = selectedImage {
                        Button {
                            photoDestination = .preview
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(.rect(cornerRadius: DS.Radius.xl))
                        }
                        .accessibilityLabel("Ver foto del producto")
                    } else {
                        Menu {
                            photoSourceItems
                        } label: {
                            VStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Agregar Foto")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .frame(width: 100, height: 100)
                            .background(Color(.systemGray5), in: .rect(cornerRadius: DS.Radius.xl))
                        }
                    }

                    Menu {
                        photoSourceItems
                    } label: {
                        Image(systemName: selectedImage != nil ? "pencil.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.blue).frame(width: 28, height: 28))
                            // Same look as before; the tap area grows to 44pt.
                            .frame(width: DS.minTapSize, height: DS.minTapSize)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel(selectedImage != nil ? "Cambiar foto" : "Agregar foto")
                    .offset(x: DS.Spacing.xs, y: DS.Spacing.xs)

                    if isLiftingSubject {
                        ProgressView()
                            .frame(width: 100, height: 100)
                            .background(Color.black.opacity(0.3), in: .rect(cornerRadius: DS.Radius.xl))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Imagen del Producto (Opcional)")
        }
    }

    @ViewBuilder
    private var photoSourceItems: some View {
        if CameraPicker.isAvailable {
            Button("Tomar Foto", systemImage: "camera") {
                photoSource = .camera
                photoDestination = .camera
            }
        }
        Button("Elegir de la Biblioteca", systemImage: "photo.on.rectangle") {
            photoSource = .library
            photoDestination = .library
        }
        if selectedImage != nil {
            Button("Eliminar Foto", systemImage: "trash", role: .destructive) {
                selectedImage = nil
                originalCroppedImage = nil
                liftedImage = nil
                backgroundRemoved = true
            }
        }
    }

    @ViewBuilder
    private func photoScreen(for destination: PhotoDestination) -> some View {
        switch destination {
        case .camera:
            CameraPicker(
                onPicked: { photoDestination = .crop($0) },
                onCancel: { photoDestination = nil }
            )
            .ignoresSafeArea()
        case .library:
            LibraryPicker(
                onPicked: { photoDestination = .crop($0) },
                onCancel: { photoDestination = nil }
            )
        case .crop(let image):
            cropView(for: image)
        case .preview:
            if let originalCroppedImage {
                ProductPhotoPreviewView(
                    liftedImage: liftedImage,
                    originalImage: originalCroppedImage,
                    backgroundRemoved: $backgroundRemoved,
                    isLifting: isLiftingSubject,
                    onRetake: { photoDestination = photoSource },
                    onDone: { photoDestination = nil }
                )
            }
        }
    }

    private func cropView(for image: UIImage) -> some View {
        SwiftyCropView(
            imageToCrop: image,
            maskShape: .square,
            // ponytail: SwiftyCrop scales magnification gesture magnitude
            // by 0.1 * zoomSensitivity internally, so the default (1.0) only
            // applies 10% of the pinch as zoom. 8 gets close to a native,
            // 1:1-feeling pinch; retune if it still feels off.
            configuration: SwiftyCropConfiguration(zoomSensitivity: 8),
            onCancel: { photoDestination = nil }
        ) { croppedImage in
            guard let croppedImage else {
                photoDestination = nil
                return
            }
            originalCroppedImage = croppedImage
            liftedImage = nil
            backgroundRemoved = true
            selectedImage = croppedImage
            // Straight to the preview; it shows a spinner until lifting ends.
            photoDestination = .preview
            Task {
                isLiftingSubject = true
                let lifted = await SubjectLifter.liftSubject(from: croppedImage)
                // Reference-identical result means lifting had no
                // effect (no clear subject, or it failed) — leave
                // the toggle hidden rather than offering a no-op.
                if lifted !== croppedImage {
                    liftedImage = lifted
                    selectedImage = lifted
                }
                isLiftingSubject = false
            }
        }
    }

    // MARK: - Margin Preview

    private var marginPreviewRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Ganancia por Unidad")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let profit = viewModel.profitPerUnit {
                    Text(formatCurrency(profit))
                        .font(.headline)
                        .foregroundStyle((profit >= 0 ? Tone.positive : .critical).color)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text("Margen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let margin = viewModel.marginPercent {
                    Text(String(format: "%.1f%%", margin))
                        .font(.headline)
                        .foregroundStyle(Margin.tone(forPercent: margin).color)
                }
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.l) {
                ProgressView()
                    .controlSize(.large)

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
            .padding(DS.Spacing.xxxl)
            .background(.regularMaterial, in: .rect(cornerRadius: DS.Radius.xl))
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
    @Published var soldAtAllLocations = true
    @Published var selectedSupplier: Supplier?
    /// One per product being created: a retry (or the offline queue's replay) of this create reuses it.
    let clientRequestId = UUID().uuidString

    // State
    @Published var isSubmitting = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showSuccess = false
    @Published var successMessage = ""
    @Published var suppliers: [Supplier] = []

    private let apiClient = APIClient.shared

    func loadSuppliers() async {
        do {
            let response: SupplierListResponse = try await apiClient.request(endpoint: .listSuppliers)
            suppliers = response.data
        } catch {
            // Optional — the picker just shows empty if this fails.
            print("Failed to load suppliers: \(error)")
        }
    }

    /// How the form started (e.g. with a scanned SKU): the baseline for
    /// "has the user entered anything?".
    private let start: ProductDraft

    init(prefillSku: String? = nil) {
        let prefill = prefillSku?.isEmpty == false ? prefillSku : nil
        start = ProductDraft(prefillSku: prefill)
        if let prefill {
            sku = prefill
        }
    }

    /// Unsaved work the form protects (no swipe-to-dismiss, Cancelar asks).
    /// The photo lives in the view, so it's passed in.
    func hasChanges(hasPhoto: Bool) -> Bool {
        var draft = ProductDraft()
        draft.name = name
        draft.sku = sku
        draft.description = description
        draft.sellingPrice = sellingPrice
        draft.costPrice = costPrice
        draft.initialStock = initialStock
        draft.hasInitialStock = hasInitialStock
        draft.syncToSquare = syncToSquare
        draft.soldAtAllLocations = soldAtAllLocations
        draft.supplierId = selectedSupplier?.id
        draft.hasPhoto = hasPhoto
        return draft.hasChanges(from: start)
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
        guard let price = sellingPrice, let cost = costPrice else { return nil }
        return Margin.percent(price: price, cost: cost)
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
                supplierId: hasInitialStock ? selectedSupplier?.id : nil,
                locationId: locationId,
                syncToSquare: syncToSquare,
                soldAtAllLocations: soldAtAllLocations,
                clientRequestId: clientRequestId
            )
            
            let response: APIResponse<CreateProductResponse> = try await apiClient.request(
                endpoint: .createProduct,
                body: request
            )
            
            let data = try response.requireData()
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
        } catch NetworkError.queuedForSync {
            // The queued replay carries this create's clientRequestId, so it
            // can't duplicate itself; creating the product again from a new
            // form would. No product id exists yet, so image upload can't run.
            successMessage = "Sin conexión. \"\(name)\" se creará automáticamente cuando vuelva la conexión — evita crearlo de nuevo mientras tanto."
            showSuccess = true
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
