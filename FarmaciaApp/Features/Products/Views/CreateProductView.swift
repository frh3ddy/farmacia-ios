import SwiftUI
import FarmaciaKit

// MARK: - Create Product View
//
// Design-system pilot (tasks/design-system-epic.md): DS tokens, AmountField,
// Margin/Tone, .formKeyboard. Presentation rules:
//   - The photo flow (camera/library → crop → preview) is FarmaciaKit
//     `PhotoFlow` on one full-screen cover (`.productPhotoFlow`), shared with
//     the product detail.
//   - The photo source is a `Menu` (no dialog to animate away before the camera
//     or library can open).
//   - The supplier is chosen by a push, not a sheet.

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
    @State private var photoFlow = PhotoFlow<UIImage>()
    @State private var showDiscardConfirmation = false

    /// Anything entered (photo included): the sheet can't be swiped away and
    /// Cancelar asks before discarding it.
    private var hasUnsavedChanges: Bool {
        viewModel.hasChanges(hasPhoto: selectedImage != nil)
    }

    private enum Field: Hashable {
        case name, sku, gtin, sellingPrice, quantity, unitCost, description
    }
    @FocusState private var focusedField: Field?

    /// Más detalles: the optional fields, collapsed unless they already hold
    /// something — `ProductDraft.hasDetails`.
    @State private var showsDetails: Bool

    /// Top to bottom, skipping rows that aren't shown.
    private var focusOrder: FocusOrder<Field> {
        FocusOrder([.name, .sku, .gtin, .sellingPrice, .quantity, .unitCost]
            + (showsDetails ? [.description] : []))
    }

    // Optional prefilled SKU (e.g. from barcode scanner) — seeded directly
    // into the StateObject at construction time rather than via .onAppear,
    // since .onAppear on a Form inside a freshly-presented sheet doesn't
    // reliably fire in time on the very first presentation, leaving the
    // SKU field blank on the first scan.
    /// The created product, so the list it was opened from shows it right
    /// away (ProductsViewModel.insertProduct).
    private let onCreated: ((Product) -> Void)?

    init(prefillBarcode: String? = nil, onCreated: ((Product) -> Void)? = nil) {
        self.onCreated = onCreated
        _viewModel = StateObject(wrappedValue: CreateProductViewModel(prefillBarcode: prefillBarcode))
        _showsDetails = State(initialValue: ProductDraft(prefillBarcode: prefillBarcode).hasDetails)
    }

    var body: some View {
        NavigationStack {
            // Layout (tasks/form-ux-polish-epic.md): essentials first — photo,
            // name, price — as labelled rows; initial stock behind its switch;
            // everything optional under Más detalles.
            Form {
                photoSection

                Section {
                    LabeledContent("Nombre") {
                        TextField("Nombre", text: $viewModel.name, prompt: Text("Ej. Paracetamol 500 mg"))
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .formField(.name, focus: $focusedField)
                    }

                    // With the essentials, not under Más detalles: empty shows
                    // "Automático", so a missing SKU is visible at a glance.
                    LabeledContent("SKU") {
                        TextField("SKU", text: $viewModel.sku, prompt: Text("Automático"))
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .formField(.sku, focus: $focusedField)
                    }

                    LabeledContent("Código de barras") {
                        TextField("Código de barras", text: $viewModel.gtin, prompt: Text("Opcional"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .formField(.gtin, focus: $focusedField)
                    }

                    AmountField(
                        "Precio",
                        prefix: "$",
                        unit: "MXN",
                        value: $viewModel.sellingPrice,
                        focus: $focusedField,
                        field: .sellingPrice
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        issueHints([.barcodeInvalid, .priceNotPositive])
                        Text("Sin SKU, se genera uno automáticamente. El precio es el que los clientes pagan en caja.")
                    }
                }

                // No switch: most new products arrive with stock, so the fields
                // are always here and a quantity is what creates it
                // (ProductDraft.createsInitialStock).
                Section {
                    AmountField(
                        "Cantidad",
                        unit: "UDS",
                        value: $viewModel.initialStock,
                        focus: $focusedField,
                        field: .quantity
                    )

                    AmountField(
                        "Costo por unidad",
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
                        LabeledContent("Proveedor", value: viewModel.selectedSupplier?.name ?? "Ninguno")
                    }
                } header: {
                    Text("Inventario inicial")
                } footer: {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        issueHints([.quantityNeeded, .costNeeded])
                        Text("Sin cantidad, el producto se crea sin existencias. Con cantidad, se registra como saldo inicial en esta sucursal.")
                    }
                }

                if viewModel.showMarginPreview {
                    Section("Margen") {
                        marginPreviewRow
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showsDetails) {
                        TextField("Descripción", text: $viewModel.description, axis: .vertical)
                            .lineLimit(2...4)
                            .formField(.description, focus: $focusedField)

                        Toggle("Vender en todas las sucursales", isOn: $viewModel.soldAtAllLocations)

                        Toggle("Sincronizar con Square", isOn: $viewModel.syncToSquare)
                    } label: {
                        MoreDetailsLabel(hasHiddenDetails: !showsDetails && viewModel.hasDetails)
                    }
                } footer: {
                    if showsDetails {
                        Text(detailsFooter)
                    }
                }
            }
            .formKeyboard(focus: $focusedField, order: focusOrder)
            // Swiping the sheet down would lose what's been entered.
            .interactiveDismissDisabled(hasUnsavedChanges)
            .productPhotoFlow($photoFlow, onCropped: photoCropped) {
                if let originalCroppedImage {
                    ProductPhotoPreviewView(
                        liftedImage: liftedImage,
                        originalImage: originalCroppedImage,
                        backgroundRemoved: $backgroundRemoved,
                        isLifting: isLiftingSubject,
                        onRetake: { photoFlow.retake() },
                        onDone: { photoFlow.cancel() }
                    )
                }
            }
            .onChange(of: backgroundRemoved) { _, removed in
                guard let originalCroppedImage else { return }
                selectedImage = removed ? (liftedImage ?? originalCroppedImage) : originalCroppedImage
            }
            .task {
                await viewModel.loadSuppliers()
            }
            .onChange(of: viewModel.createdProduct) { _, product in
                if let product { onCreated?(product) }
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
        // On the NavigationStack, not the Cancelar button: attached to the button,
        // iOS 26 shrinks the dialog back into it before the sheet may start
        // closing — a half-second stall after Descartar (measured on device).
        // Not on the Form either: it already hosts other presentations.
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

    /// What the Más detalles settings mean, for the choices made.
    private var detailsFooter: String {
        var lines: [String] = []
        if !viewModel.soldAtAllLocations {
            lines.append("Solo se vende en esta sucursal; no aparece en las demás.")
        }
        lines.append(viewModel.syncToSquare
            ? "Aparece en Square POS para venderse."
            : "Solo se lleva aquí; no aparece en Square POS.")
        return lines.joined(separator: " ")
    }

    // MARK: - Photo

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    if let image = selectedImage {
                        Button {
                            photoFlow.step = .preview
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
                            .background(.fill.tertiary, in: .rect(cornerRadius: DS.Radius.xl))
                        }
                    }

                    Menu {
                        photoSourceItems
                    } label: {
                        Image(systemName: selectedImage != nil ? "pencil.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .background(Circle().fill(.tint).frame(width: 28, height: 28))
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
        }
    }

    @ViewBuilder
    private var photoSourceItems: some View {
        if CameraPicker.isAvailable {
            Button("Tomar Foto", systemImage: "camera") {
                photoFlow.start(.camera)
            }
        }
        Button("Elegir de la Biblioteca", systemImage: "photo.on.rectangle") {
            photoFlow.start(.library)
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

    /// The square photo, as the flow moves on to the preview (which shows a
    /// spinner until background removal ends).
    private func photoCropped(_ croppedImage: UIImage) {
        originalCroppedImage = croppedImage
        liftedImage = nil
        backgroundRemoved = true
        selectedImage = croppedImage
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

    /// The section's share of `ProductDraft.issues`, in words next to the fields they're about.
    private func issueHints(_ shown: [ProductDraft.Issue]) -> some View {
        ForEach(viewModel.issues.filter(shown.contains), id: \.self) { issue in
            StatusLabel(issue.message, tone: .caution)
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
                    Text("Sincronizando con Square...")
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
            viewModel.errorMessage = "No hay una sucursal seleccionada"
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

// MARK: - Preview

#Preview {
    CreateProductView()
        .environmentObject(AuthManager.shared)
}
