import SwiftUI
import FarmaciaKit

// MARK: - Sueltos
//
// Links a box product to its suelto at the session's store (OWNER/MANAGER),
// like the web's "Vincular caja con suelto" card. Each store picks its own
// suelto; Piezas por caja is the box's, the same at every store.
// tasks/sueltos-link-epic.md

struct SueltosView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var box: Product?
    @State private var suelto: Product?
    /// The box's suelto at this store, when it has one.
    @State private var currentSuelto: Product?
    @State private var currentSueltoFailed = false
    @State private var quantityText = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var confirmUnlink = false

    @FocusState private var focusedField: SueltosField?

    private var storeName: String { authManager.currentLocation?.name ?? "esta tienda" }

    var body: some View {
        Form {
            Section {
                Text("Se vincula solo en \(storeName); cada sucursal elige su propio suelto.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section { StatusLabel(errorMessage, tone: .critical) }
            }
            if let successMessage {
                Section { StatusLabel(successMessage, tone: .positive) }
            }

            Section("Producto de caja") {
                ProductSearchPicker(selected: $box, placeholder: "Paracetamol 500mg Caja…",
                                    field: .box, focus: $focusedField)
                if box?.looseProductId != nil {
                    // The name loads after; unlinking doesn't need it.
                    LabeledContent("Suelto actual", value: LooseLinkForm.currentSueltoText(
                        name: currentSuelto?.displayName, failed: currentSueltoFailed))
                    Button("Desvincular", role: .destructive) { confirmUnlink = true }
                        .disabled(isSubmitting)
                }
            }

            Section("Producto suelto") {
                ProductSearchPicker(selected: $suelto, placeholder: "Paracetamol 500mg Suelto…",
                                    field: .suelto, focus: $focusedField)
            }

            Section {
                TextField("20", text: $quantityText)
                    .keyboardType(.numberPad)
                    .formField(.quantity, focus: $focusedField)
            } header: {
                Text("Piezas por caja")
            } footer: {
                Text("Aplica en todas las sucursales.")
            }
        }
        // Pinned like the other forms' action, so it's never below the fold.
        .primaryActionBar(PrimaryActionBar(
            title: "Vincular", doneTitle: "Vinculado",
            isSubmitting: isSubmitting, isDone: false
        ) { Task { await link() } })
        // Scrolls a focused search field up so its results clear the keyboard,
        // and adds Listo above the number pad (it has no return key).
        .formKeyboard(focus: $focusedField, order: FocusOrder([.box, .suelto, .quantity]))
        .navigationTitle("Sueltos")
        .storeStrip()
        .task(id: box?.id) { await boxChanged() }
        .confirmationDialog("¿Desvincular el suelto en \(storeName)?", isPresented: $confirmUnlink, titleVisibility: .visible) {
            Button("Desvincular", role: .destructive) { Task { await unlink() } }
        } message: {
            Text("Las otras sucursales conservan su propio suelto.")
        }
    }

    /// Prefill Piezas por caja and show this store's current suelto.
    private func boxChanged() async {
        quantityText = LooseLinkForm.prefill(boxQuantity: box?.quantity)
        currentSuelto = nil
        currentSueltoFailed = false
        guard let looseId = box?.looseProductId, let locationId = authManager.currentLocation?.id else { return }
        do {
            let response: ProductDetailResponse = try await APIClient.shared.request(
                endpoint: .getProduct(id: looseId),
                queryParams: ["locationId": locationId]
            )
            guard !Task.isCancelled else { return }
            currentSuelto = response.data
        } catch {
            guard !Task.isCancelled else { return }
            currentSueltoFailed = true
        }
    }

    private func link() async {
        successMessage = nil
        switch LooseLinkForm.validate(boxId: box?.id, boxQuantity: box?.quantity,
                                      sueltoId: suelto?.id, quantityText: quantityText) {
        case .fail(let message):
            errorMessage = message
        case .send(let request):
            guard let box, let suelto else { return }
            if await send(request, boxId: box.id) {
                successMessage = LooseLinkForm.linkedText(box: box.displayName, suelto: suelto.displayName, store: storeName)
                reset()
            }
        }
    }

    private func unlink() async {
        successMessage = nil
        guard let box else { return }
        if await send(.unlink, boxId: box.id) {
            successMessage = LooseLinkForm.unlinkedText(box: box.displayName, store: storeName)
            reset()
        }
    }

    /// The server's message (e.g. "… no se vende en Oriente") is shown as is.
    private func send(_ request: LooseLinkRequest, boxId: String) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        do {
            try await APIClient.shared.requestVoid(endpoint: .setLooseLink(productId: boxId), body: request)
            return true
        } catch let error as NetworkError {
            errorMessage = error.errorDescription ?? "No se pudo vincular"
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }

    private func reset() {
        box = nil
        suelto = nil
        currentSuelto = nil
        quantityText = ""
    }
}

// MARK: - Product Search Picker

fileprivate enum SueltosField: Hashable { case box, suelto, quantity }

/// Name/SKU search over this store's products (live API, not the cache), pick one.
private struct ProductSearchPicker: View {
    @Binding var selected: Product?
    let placeholder: String
    let field: SueltosField
    var focus: FocusState<SueltosField?>.Binding

    @EnvironmentObject private var authManager: AuthManager
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var searchError: String?

    var body: some View {
        if let selected {
            HStack {
                ProductOptionLabel(product: selected)
                Spacer()
                Button("Cambiar") { self.selected = nil }
                    .buttonStyle(.borderless)
            }
        } else {
            TextField(placeholder, text: $query)
                .autocorrectionDisabled()
                .formField(field, focus: focus)
                .task(id: query) { await search() }
            if isSearching {
                ProgressView().frame(maxWidth: .infinity)
            }
            if let searchError {
                StatusLabel(searchError, tone: .critical)
            }
            ForEach(results) { product in
                Button {
                    selected = product
                    query = ""
                    results = []
                } label: {
                    ProductOptionLabel(product: product)
                }
                .tint(.primary)
            }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchError = nil
        guard !text.isEmpty, let locationId = authManager.currentLocation?.id else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300)) // debounce: a newer query cancels this one
        guard !Task.isCancelled else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            let response: ProductListResponse = try await APIClient.shared.request(
                endpoint: .listProducts,
                queryParams: ["search": text, "limit": "8", "locationId": locationId]
            )
            guard !Task.isCancelled else { return }
            results = response.data
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            searchError = "No se pudo buscar. Revisa la conexión e intenta de nuevo."
        }
    }
}

private struct ProductOptionLabel: View {
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(product.displayName)
            Text(LooseLinkForm.pickerSubtitle(sku: product.sku, quantity: product.quantity,
                                              linked: product.looseProductId != nil))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
