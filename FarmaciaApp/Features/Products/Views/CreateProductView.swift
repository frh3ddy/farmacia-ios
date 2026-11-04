import SwiftUI
import CodeScanner
import FarmaciaKit

// MARK: - Create Product View
//
// Layout (tasks/inventory-forms-redesign-epic.md): photo beside the name (as in
// Contacts) → Precio (cost → margin → price) → Identificación → Inventario
// inicial → Disponibilidad → Descripción. Required sections have no marker;
// optional ones say "Opcional". One action at the bottom, always enabled;
// what's missing shows on the field after a tap.
// Presentation rules:
//   - The photo flow (camera/library → crop → preview) is FarmaciaKit
//     `PhotoFlow` on one full-screen cover (`.productPhotoFlow`), shared with
//     the product detail.
//   - The photo source is a `Menu` (no dialog to animate away before the camera
//     or library can open).
//   - The supplier is chosen by a push, not a sheet. The barcode scanner sheet
//     hangs off its own row, away from the photo flow's presentations.

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
    @State private var showScanner = false

    /// The margin chip picked; the price follows the cost while it's on.
    @State private var marginPick = MarginPick()
    /// Failed taps on Crear: errors show from the first one; each one shakes.
    @State private var attempts = 0

    /// Anything entered (photo included): the sheet can't be swiped away and
    /// Cancelar asks before discarding it.
    private var hasUnsavedChanges: Bool {
        viewModel.hasChanges(hasPhoto: selectedImage != nil)
    }

    private enum Field: Hashable {
        case name, unitCost, sellingPrice, sku, gtin, quantity, description
    }
    @FocusState private var focusedField: Field?

    /// Top to bottom.
    private let focusOrder = FocusOrder<Field>([.name, .unitCost, .sellingPrice, .sku, .gtin, .quantity, .description])

    private func field(for issue: ProductDraft.Issue) -> Field {
        switch issue {
        case .nameMissing: .name
        case .costNeeded: .unitCost
        case .priceMissing, .priceNotPositive: .sellingPrice
        case .barcodeInvalid: .gtin
        }
    }

    /// The message under `field`, once the user has tried to create.
    private func error(_ field: Field) -> String? {
        guard attempts > 0 else { return nil }
        return viewModel.issues.first { self.field(for: $0) == field }?.message
    }

    private var createsStock: Bool { (viewModel.initialStock ?? 0) > 0 }

    // Optional prefilled barcode (from the scanner) — seeded directly into the
    // StateObject at construction time rather than via .onAppear, since
    // .onAppear on a Form inside a freshly-presented sheet doesn't reliably
    // fire in time on the very first presentation.
    /// The created product, so the list it was opened from shows it right
    /// away (ProductsViewModel.insertProduct).
    private let onCreated: ((Product) -> Void)?

    init(prefillBarcode: String? = nil, onCreated: ((Product) -> Void)? = nil) {
        self.onCreated = onCreated
        _viewModel = StateObject(wrappedValue: CreateProductViewModel(prefillBarcode: prefillBarcode))
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                priceSection
                identificationSection
                initialStockSection

                Section {
                    Toggle("Vender en todas las sucursales", isOn: $viewModel.soldAtAllLocations)
                    Toggle("Sincronizar con Square", isOn: $viewModel.syncToSquare)
                } header: {
                    Text("Disponibilidad")
                } footer: {
                    Text(availabilityFooter)
                }

                Section {
                    TextField("Descripción", text: $viewModel.description, prompt: Text("Presentación, uso, notas"), axis: .vertical)
                        .lineLimit(2...4)
                        .formField(.description, focus: $focusedField)
                } header: {
                    OptionalHeader(title: "Descripción")
                }
            }
            .disabled(viewModel.isSubmitting || viewModel.isDone)
            .primaryActionBar(PrimaryActionBar(
                title: "Crear producto",
                doneTitle: "Producto creado",
                summary: attempts > 0 && !viewModel.issues.isEmpty ? "Revisa los campos marcados" : nil,
                summaryTone: .critical,
                isSubmitting: viewModel.isSubmitting,
                isDone: viewModel.isDone,
                action: submit
            ))
            .sensoryFeedback(.error, trigger: attempts)
            .formKeyboard(focus: $focusedField, order: focusOrder)
            // Swiping the sheet down would lose what's been entered.
            .interactiveDismissDisabled(hasUnsavedChanges || viewModel.isSubmitting)
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
            .task(id: viewModel.isDone) {
                guard viewModel.isDone else { return }
                // Long enough to read the checkmark, short enough not to wait on.
                try? await Task.sleep(for: .milliseconds(600))
                dismiss()
            }
            .navigationTitle("Nuevo producto")
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
                    .disabled(viewModel.isSubmitting || viewModel.isDone)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert(
                viewModel.successMessage.hasPrefix("Sin conexión") ? "Sin conexión" : "Producto creado",
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

    /// What the Disponibilidad switches mean, for the choices made.
    private var availabilityFooter: String {
        var lines: [String] = []
        if !viewModel.soldAtAllLocations {
            lines.append("Solo se vende en esta sucursal; no aparece en las demás.")
        }
        lines.append(viewModel.syncToSquare
            ? "Aparece en Square POS para venderse."
            : "Solo se lleva aquí; no aparece en Square POS.")
        return lines.joined(separator: " ")
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            HStack(alignment: .top, spacing: DS.Spacing.m) {
                photoButton

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Wraps and grows, so a long medicine name stays readable.
                    // Return moves on instead of adding a line break.
                    TextField("Nombre", text: $viewModel.name, prompt: Text("Nombre del producto"), axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .formField(.name, focus: $focusedField)
                        .onChange(of: viewModel.name) { _, name in
                            guard name.contains("\n") else { return }
                            viewModel.name = name.replacing("\n", with: "")
                            focusedField = .unitCost
                        }

                    if let hint = ProductName.lengthHint(viewModel.name) {
                        Text(hint.text)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(hint.tone == .neutral ? .secondary : hint.tone.color)
                    }
                }
                .frame(minHeight: 64, alignment: .center)
            }
            .fieldError(error(.name), shake: attempts, field: Field.name)
        }
    }

    private var priceSection: some View {
        Section {
            AmountField(
                "Costo por unidad",
                prefix: "$",
                unit: "MXN",
                value: $viewModel.costPrice,
                focus: $focusedField,
                field: .unitCost
            )
            .fieldError(error(.unitCost), shake: attempts, field: Field.unitCost)

            if let cost = viewModel.costPrice, cost > 0 {
                    MarginChips(
                        options: PriceSuggestion.chips.map { margin in
                            .init(label: "\(Int(margin))%", margin: margin,
                                  price: PriceSuggestion.price(cost: cost, marginPercent: margin))
                        },
                        selected: marginPick.selected,
                        onSelect: { margin in
                            marginPick.selected = margin
                            viewModel.sellingPrice = marginPick.price(forCost: cost)
                        },
                        onOther: {
                            marginPick.selected = nil
                            focusedField = .sellingPrice
                        },
                        result: viewModel.sellingPrice.flatMap { price in
                            Margin.percent(price: price, cost: cost).map { ($0, price - cost) }
                        },
                        onRelease: { marginPick.selected = nil }
                    )
                    .transition(.opacity)
            }

            AmountField(
                "Precio de venta",
                prefix: "$",
                unit: "MXN",
                value: $viewModel.sellingPrice,
                focus: $focusedField,
                field: .sellingPrice
            )
            .fieldError(error(.sellingPrice), shake: attempts, field: Field.sellingPrice)
        } header: {
            Text("Precio")
        } footer: {
            Text(marginPick.selected == nil
                ? "Lo que paga el cliente en caja y en Square POS."
                : "Sugerido con el margen elegido, redondeado a $0.50. Si cambias el costo, el precio se recalcula; escribe un precio para fijarlo.")
        }
        .animation(.default, value: viewModel.costPrice != nil)
        .onChange(of: viewModel.costPrice) { _, cost in
            if let price = marginPick.price(forCost: cost) {
                viewModel.sellingPrice = price
            }
        }
        .onChange(of: viewModel.sellingPrice) { _, price in
            marginPick.priceTyped(price, cost: viewModel.costPrice)
        }
    }

    private var identificationSection: some View {
        Section {
            LabeledContent("SKU") {
                TextField("SKU", text: $viewModel.sku, prompt: Text("Automático"))
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .formField(.sku, focus: $focusedField)
            }
            // Row-level id: .formKeyboard scrolls to it (see .fieldError).
            .id(Field.sku)

            HStack(spacing: DS.Spacing.s) {
                LabeledContent("Código de barras") {
                    TextField("Código de barras", text: $viewModel.gtin, prompt: Text("Opcional"))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .formField(.gtin, focus: $focusedField)
                }
                Button("Escanear código de barras", systemImage: "barcode.viewfinder") {
                    focusedField = nil
                    showScanner = true
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: DS.minTapSize, height: DS.minTapSize)
                .buttonStyle(.borderless)
            }
            .fieldError(error(.gtin), shake: attempts, field: Field.gtin)
            // On this row, not the Form: the Form hosts the photo flow's cover.
            .sheet(isPresented: $showScanner) { barcodeScanner }
        } header: {
            OptionalHeader(title: "Identificación")
        } footer: {
            Text("Escanea el código del empaque. Sin SKU, se genera uno automáticamente.")
        }
    }

    private var initialStockSection: some View {
        Section {
            AmountField(
                "Cantidad",
                unit: "UDS",
                value: $viewModel.initialStock,
                focus: $focusedField,
                field: .quantity
            )

            // Only meaningful with stock to record.
            if createsStock {
                NavigationLink {
                    SupplierPickerView(
                        suppliers: $viewModel.suppliers,
                        selectedSupplier: $viewModel.selectedSupplier
                    )
                } label: {
                    LabeledContent("Proveedor", value: viewModel.selectedSupplier?.name ?? "Sin proveedor")
                }
            }
        } header: {
            OptionalHeader(title: "Inventario inicial")
        } footer: {
            Text(createsStock
                ? "Se registra como saldo inicial en esta sucursal, al costo por unidad de Precio."
                : "Sin cantidad, el producto se crea sin existencias.")
        }
        .animation(.default, value: createsStock)
    }

    private var barcodeScanner: some View {
        NavigationStack {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14],
                scanMode: .once,
                showViewfinder: true,
                shouldVibrateOnSuccess: true
            ) { result in
                if case .success(let scan) = result {
                    // A 14-digit read of an EAN-13 is saved as the 13 digits on the box.
                    viewModel.gtin = BarcodeLookup.newProductBarcode(scan.string)
                }
                showScanner = false
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Escanear código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showScanner = false }
                }
            }
        }
    }

    // MARK: - Photo

    /// 64pt, beside the name. A menu: take, choose, view or remove.
    private var photoButton: some View {
        Menu {
            if selectedImage != nil {
                Button("Ver foto", systemImage: "eye") {
                    photoFlow.step = .preview
                }
            }
            photoSourceItems
        } label: {
            Group {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    VStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                        Text("Foto")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tint)
                }
            }
            .frame(width: 64, height: 64)
            .background(.fill.tertiary)
            .clipShape(.rect(cornerRadius: DS.Radius.l))
            .overlay {
                if isLiftingSubject {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3), in: .rect(cornerRadius: DS.Radius.l))
                }
            }
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(selectedImage != nil ? "Foto del producto" : "Agregar foto")
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

    // MARK: - Actions

    private func submit() {
        guard !viewModel.isSubmitting, !viewModel.isDone else { return }
        if let first = viewModel.issues.first {
            attempts += 1
            // Focus scrolls the field into view (.formKeyboard) and opens its keyboard.
            focusedField = field(for: first)
            AccessibilityNotification.Announcement(first.message).post()
            return
        }
        guard let locationId = authManager.currentLocation?.id else {
            viewModel.errorMessage = "No hay una sucursal seleccionada"
            viewModel.showError = true
            return
        }
        // Set before the Task runs, so a second tap can't slip in first.
        viewModel.isSubmitting = true
        focusedField = nil
        Task {
            await viewModel.createProduct(locationId: locationId, image: selectedImage)
        }
    }
}

// MARK: - Preview

#Preview {
    CreateProductView()
        .environmentObject(AuthManager.shared)
}
