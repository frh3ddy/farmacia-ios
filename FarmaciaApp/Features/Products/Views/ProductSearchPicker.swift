import SwiftUI
import FarmaciaKit
import CodeScanner

// MARK: - Product Search Picker
//
// Shared by Sueltos and Transferencias: type a name/SKU or scan, pick a product.

/// Name/SKU search over this store's products (live API, not the cache), or a
/// barcode scan, pick one.
struct ProductSearchPicker<Field: Hashable>: View {
    @Binding var selected: Product?
    let placeholder: String
    let field: Field
    var focus: FocusState<Field?>.Binding
    let scanLabel: String
    /// The line under each product's name (SKU, stock, and what this screen cares about).
    let subtitle: (Product) -> String

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
                ProductOptionLabel(product: selected, subtitle: subtitle(selected))
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
                Button(scanLabel, systemImage: "barcode.viewfinder") {
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
                    ProductOptionLabel(product: product, subtitle: subtitle(product))
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
            switch BarcodeLookup.pick(code: code, resultCount: matches.count, store: storeName) {
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

struct ProductOptionLabel: View {
    let product: Product
    let subtitle: String

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            ProductThumbnail(product: product)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(product.displayName)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 48pt, like ProductSummaryRow: the photo makes the right product easy to spot.
struct ProductThumbnail: View {
    let url: String?

    init(product: Product) { url = product.squareImageUrl }
    init(url: String?) { self.url = url }

    var body: some View {
        CachedProductImage(url: url, targetSize: CGSize(width: 48, height: 48)) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
        }
        .frame(width: 48, height: 48)
        .background(.fill.tertiary, in: .rect(cornerRadius: DS.Radius.m))
        .clipShape(.rect(cornerRadius: DS.Radius.m))
        .accessibilityHidden(true)
    }
}
