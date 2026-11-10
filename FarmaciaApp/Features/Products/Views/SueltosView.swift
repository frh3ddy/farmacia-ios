import SwiftUI
import FarmaciaKit
import CodeScanner

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
    /// This store's linked pairs; nil until the first load.
    @State private var links: [LooseLinkPair]?
    @State private var linksFailed = false

    @FocusState private var focusedField: SueltosField?

    private var storeName: String { authManager.currentLocation?.name ?? "esta tienda" }

    private static func pickerSubtitle(_ product: Product) -> String {
        LooseLinkForm.pickerSubtitle(sku: product.sku, quantity: product.quantity, linked: product.looseProductId != nil)
    }

    var body: some View {
        ScrollViewReader { proxy in
            form(proxy)
        }
    }

    private func form(_ proxy: ScrollViewProxy) -> some View {
        Form {
            Section {
                Text("Se vincula solo en \(storeName); cada sucursal elige su propio suelto.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .id(SueltosAnchor.top)

            if let errorMessage {
                Section { StatusLabel(errorMessage, tone: .critical) }
            }
            if let successMessage {
                Section { StatusLabel(successMessage, tone: .positive) }
            }

            Section("Producto de caja") {
                ProductSearchPicker(selected: $box, placeholder: "Paracetamol 500mg Caja…",
                                    field: .box, focus: $focusedField, scanLabel: "Escanear caja",
                                    subtitle: Self.pickerSubtitle)
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
                                    field: .suelto, focus: $focusedField, scanLabel: "Escanear suelto",
                                    subtitle: Self.pickerSubtitle)
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

            linkedSection(proxy)
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
        .task { await loadLinks() }
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
                await loadLinks()
            }
        }
    }

    private func unlink() async {
        successMessage = nil
        guard let box else { return }
        if await send(.unlink, boxId: box.id) {
            successMessage = LooseLinkForm.unlinkedText(box: box.displayName, store: storeName)
            reset()
            await loadLinks()
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

    // MARK: Linked pairs

    @ViewBuilder
    private func linkedSection(_ proxy: ScrollViewProxy) -> some View {
        Section {
            if linksFailed {
                StatusLabel("No se pudieron cargar los productos vinculados. Revisa la conexión.", tone: .critical)
            } else if let links {
                if links.isEmpty {
                    Text(LooseLinkForm.linkedEmptyText(store: storeName))
                        .foregroundStyle(.secondary)
                }
                ForEach(links) { pair in
                    Button {
                        // Load it into the form: box + suelto, and boxChanged() prefills
                        // the pieces and shows Suelto actual + Desvincular.
                        successMessage = nil
                        errorMessage = nil
                        box = pair.box
                        suelto = pair.loose
                        withAnimation { proxy.scrollTo(SueltosAnchor.top, anchor: .top) }
                    } label: {
                        LinkedPairRow(pair: pair)
                    }
                    .tint(.primary)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        } header: {
            Text(LooseLinkForm.linkedHeader(store: storeName, count: links?.count))
        }
    }

    private func loadLinks() async {
        do {
            let response: LooseLinkListResponse = try await APIClient.shared.request(endpoint: .listLooseLinks)
            links = response.data
            linksFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            linksFailed = true
        }
    }

    private func reset() {
        box = nil
        suelto = nil
        currentSuelto = nil
        quantityText = ""
    }
}

// MARK: - Fields

fileprivate enum SueltosField: Hashable { case box, suelto, quantity }
private enum SueltosAnchor: Hashable { case top }


/// A linked pair: the box, then its suelto at this store, with both photos.
private struct LinkedPairRow: View {
    let pair: LooseLinkPair

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            ProductThumbnail(product: pair.box)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(pair.box.displayName)
                Label(pair.loose.displayName, systemImage: "arrow.turn.down.right")
                    .font(.subheadline)
                Text(LooseLinkForm.linkedRowDetail(quantity: pair.box.quantity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            ProductThumbnail(product: pair.loose)
        }
        .accessibilityElement(children: .combine)
    }
}
