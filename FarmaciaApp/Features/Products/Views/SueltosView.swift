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

// MARK: - Product Search Picker

fileprivate enum SueltosField: Hashable { case box, suelto, quantity }
private enum SueltosAnchor: Hashable { case top }

/// Name/SKU search over this store's products (live API, not the cache), or a
/// barcode scan, pick one.
private struct ProductSearchPicker: View {
    @Binding var selected: Product?
    let placeholder: String
    let field: SueltosField
    var focus: FocusState<SueltosField?>.Binding

    @EnvironmentObject private var authManager: AuthManager
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var isLookingUp = false
    @State private var searchError: String?
    /// A scan that matched nothing at this store.
    @State private var scanNotice: String?
    @State private var showScanner = false
    /// The last scan; a new scan or typing replaces it, cancelling its search.
    @State private var scan: ScannedCode?

    private struct ScannedCode: Equatable {
        let code: String
        let id = UUID()
    }

    private var storeName: String { authManager.currentLocation?.name ?? "esta tienda" }

    var body: some View {
        if let selected {
            HStack {
                ProductOptionLabel(product: selected)
                Spacer()
                Button("Cambiar") { self.selected = nil }
                    .buttonStyle(.borderless)
            }
        } else {
            HStack {
                TextField(placeholder, text: $query)
                    .autocorrectionDisabled()
                    .formField(field, focus: focus)
                    .task(id: query) { await search() }
                Button(field == .box ? "Escanear caja" : "Escanear suelto", systemImage: "barcode.viewfinder") {
                    showScanner = true
                }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            .sheet(isPresented: $showScanner) { scanner }
            .task(id: scan) {
                guard let scan else { return }
                await lookUp(scan.code)
                // Done: clear it, or "Cambiar" would bring the field back and rerun it.
                if !Task.isCancelled { self.scan = nil }
            }
            if isSearching || isLookingUp {
                ProgressView().frame(maxWidth: .infinity)
            }
            if let searchError {
                StatusLabel(searchError, tone: .critical)
            }
            if let scanNotice {
                StatusLabel(scanNotice, tone: .caution)
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
        scanNotice = nil
        guard !text.isEmpty, let locationId = authManager.currentLocation?.id else {
            results = []
            return
        }
        scan = nil // typing replaces a scan still searching
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

    private var scanner: some View {
        NavigationStack {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .qr],
                scanMode: .once,
                showViewfinder: true,
                simulatedData: ScanFlowSheet.simulatedCode,
                shouldVibrateOnSuccess: true
            ) { result in
                showScanner = false
                switch result {
                case .success(let result):
                    query = ""
                    scan = ScannedCode(code: result.string)
                case .failure:
                    scanNotice = "No se pudo usar la cámara. Revisa el permiso en Ajustes o escribe el nombre."
                }
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

    /// Exact SKU/barcode search at this store, in each GTIN form of the code
    /// (13 or 14 digits), like Productos' scanner.
    private func lookUp(_ code: String) async {
        guard let locationId = authManager.currentLocation?.id else { return }
        searchError = nil
        scanNotice = nil
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            let found = try await BarcodeLookup.searchVariants(of: code, isExact: { $0.exactMatch == true && !$0.data.isEmpty }) {
                let response: ProductListResponse = try await APIClient.shared.request(
                    endpoint: .listProducts,
                    queryParams: ["search": $0, "exact": "true", "limit": "8", "locationId": locationId]
                )
                return response
            }
            guard !Task.isCancelled else { return }
            let matches = found.exact ? found.response.data : []
            switch LooseLinkForm.scanPick(code: code, resultCount: matches.count, store: storeName) {
            case .select:
                selected = matches[0]
                results = []
            case .choose:
                results = matches
            case .notFound(let text):
                results = []
                scanNotice = text
            }
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
        HStack(spacing: DS.Spacing.m) {
            ProductThumbnail(product: product)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(product.displayName)
                Text(LooseLinkForm.pickerSubtitle(sku: product.sku, quantity: product.quantity,
                                                  linked: product.looseProductId != nil))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

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

/// 48pt, like ProductSummaryRow: the photo makes the right product easy to spot.
private struct ProductThumbnail: View {
    let product: Product

    var body: some View {
        CachedProductImage(url: product.squareImageUrl, targetSize: CGSize(width: 48, height: 48)) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
        .frame(width: 48, height: 48)
        .background(.fill.tertiary, in: .rect(cornerRadius: DS.Radius.m))
        .clipShape(.rect(cornerRadius: DS.Radius.m))
        .accessibilityHidden(true)
    }
}
