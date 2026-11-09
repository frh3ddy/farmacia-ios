import SwiftUI
import FarmaciaKit
import CodeScanner

// MARK: - Scan Flow Sheet
//
// Scanning a barcode on Productos, as one sheet: scanner → (several matches)
// a list to choose from → (no match) Nuevo Producto with the code as SKU. Each
// step replaces the sheet's content with a slide-in, so there's no closing one
// sheet and opening the next (that handoff lost the prefilled SKU on the first
// try and needed a pending-code + onDismiss workaround).
// Three modes (tasks/scan-modes-epic.md): Consultar closes the sheet and opens
// the product on Productos; Recibir and Contar open its receive / count form in
// place and come back to the scanner for the next item, with the last save in a
// strip. Where each step goes is FarmaciaKit's `ScanNext`.
// Steps are swapped, not pushed: each form has its own NavigationStack, and
// closes back here through its `onClose`.

/// What a scanned code resolves to (ProductsView looks it up: loaded products,
/// the on-device cache, then the server — FarmaciaKit `BarcodeLookup`).
enum ScanOutcome {
    case open(Product)
    case choose([Product])
    case create
}

struct ScanFlowSheet: View {
    let lookup: (String) async -> ScanOutcome
    /// Recibir and Contar are offered only to employees who can manage inventory.
    let canManageInventory: Bool
    let onOpen: (Product) -> Void
    /// A product created from an unknown code (Nuevo Producto).
    let onCreated: (Product) -> Void
    /// A receive or count saved: Productos refreshes the product's row.
    let onStockChanged: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("scanMode") private var savedMode: FarmaciaKit.ScanMode = .consult
    /// One for the whole run: the supplier list loads once, not per item.
    @StateObject private var inventoryViewModel = InventoryViewModel()
    @State private var step: Step = .scan
    @State private var isLookingUp = false
    /// The last receive or count, and its product (the strip opens it).
    @State private var recent: (save: RecentScanSave, product: Product)?
    /// The store's open Conteo inicial, so counters see that Contar is going to it.
    @State private var openCount: StockCountSession?
    @EnvironmentObject private var authManager: AuthManager

    private var mode: FarmaciaKit.ScanMode {
        FarmaciaKit.ScanMode.effective(saved: savedMode, canManageInventory: canManageInventory)
    }

    private enum Step: Equatable {
        case scan
        case choose(code: String, candidates: [Product])
        case create(code: String)
        /// The note is worked out on the way in, so it doesn't change as the save lands.
        case receive(Product, note: String?)
        case count(Product, note: String?)
    }

    var body: some View {
        Group {
            switch step {
            case .scan:
                scanner
            case .choose(let code, let candidates):
                BarcodeCandidatesList(
                    code: code,
                    candidates: candidates,
                    onSelect: { route(.matched, product: $0) },
                    onCreate: { show(.create(code: code)) },
                    onCancel: { route(.closed) }
                )
                .transition(.push(from: .trailing))
            case .create(let code):
                // The code is the new product's barcode (the server makes the SKU); a
                // 14-digit read of an EAN-13 is saved as the 13 digits on the box.
                CreateProductView(
                    prefillBarcode: BarcodeLookup.newProductBarcode(code),
                    showsInitialStock: mode.createShowsInitialStock,
                    onCreated: onCreated,
                    onClose: { product in
                        if let product { route(.created, product: product) } else { route(.closed) }
                    }
                )
                .transition(.push(from: .trailing))
            case .receive(let product, let note):
                ReceiveInventoryFormView(
                    viewModel: inventoryViewModel,
                    product: product,
                    onComplete: { quantity in saved(product, .received(quantity)) },
                    onClose: { route(.closed) },
                    note: note
                )
                .transition(.push(from: .trailing))
            case .count(let product, let note):
                AdjustmentFormView(
                    adjustmentType: .countCorrection,
                    viewModel: inventoryViewModel,
                    product: product,
                    onCounted: { before, counted in saved(product, .counted(before: before, counted: counted)) },
                    onClose: { route(.closed) },
                    note: note
                )
                .transition(.push(from: .trailing))
            }
        }
        // Not on the scanner itself: it's swapped out while a form is showing.
        .alert("Square", isPresented: $inventoryViewModel.showsSquareWarning) {
            Button("OK") {}
        } message: {
            Text(inventoryViewModel.squareWarning ?? "")
        }
        // Here, not on the strip: the strip appears with the save already in it.
        // Counts only: the receive form's button already plays it on save.
        .sensoryFeedback(.success, trigger: recent?.save) { _, save in
            if case .counted = save?.kind { true } else { false }
        }
    }

    private var scanner: some View {
        NavigationStack {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .qr],
                scanMode: .once,
                showViewfinder: true,
                simulatedData: Self.simulatedCode,
                shouldVibrateOnSuccess: true,
                completion: handleScan
            )
            .ignoresSafeArea(edges: .bottom)
            .overlay {
                if isLookingUp {
                    ProgressView("Buscando…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: DS.Radius.l))
                }
            }
            .overlay(alignment: .bottom) {
                if let recent {
                    RecentSaveStrip(text: recent.save.text) { open(recent.product) }
                }
            }
            .safeAreaInset(edge: .top) {
                if canManageInventory {
                    VStack(spacing: DS.Spacing.xs) {
                        Picker("Modo", selection: $savedMode) {
                            ForEach(FarmaciaKit.ScanMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        if mode == .count, openCount != nil {
                            Label("Conteo inicial en curso", systemImage: "checklist")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, DS.Spacing.s)
                    .background(.bar)
                }
            }
            // After the mode picker's inset, so the strip sits above it.
            .storeStrip()
            .task(id: mode) {
                guard mode == .count, let locationId = authManager.currentLocation?.id else { return }
                let active: APIResponse<StockCountSession>? = try? await APIClient.shared.request(
                    endpoint: .stockCountActive,
                    queryParams: ["locationId": locationId]
                )
                openCount = active?.data
            }
            .navigationTitle("Escanear Código")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func handleScan(result: Result<ScanResult, ScanError>) {
        switch result {
        case .success(let scanResult):
            let code = scanResult.string
            Task {
                isLookingUp = true
                let outcome = await lookup(code)
                isLookingUp = false
                switch outcome {
                case .open(let product):
                    route(.matched, product: product)
                case .choose(let candidates):
                    route(.severalMatched, code: code, candidates: candidates)
                case .create:
                    route(.unknown, code: code)
                }
            }
        case .failure:
            dismiss()
        }
    }

    private func route(_ event: ScanEvent, product: Product? = nil, code: String = "", candidates: [Product] = []) {
        switch ScanNext.after(event, in: mode) {
        case .openDetail: if let product { open(product) }
        case .receive: if let product { show(.receive(product, note: repeatNote(product, .receive))) }
        case .count: if let product { show(.count(product, note: repeatNote(product, .count))) }
        case .choose: show(.choose(code: code, candidates: candidates))
        case .create: show(.create(code: code))
        case .scan: show(.scan)
        case .close: dismiss()
        }
    }

    private func repeatNote(_ product: Product, _ mode: FarmaciaKit.ScanMode) -> String? {
        recent?.save.repeatNote(productId: product.id, mode: mode)
    }

    private func saved(_ product: Product, _ kind: RecentScanSave.Kind) {
        recent = (RecentScanSave(productId: product.id, name: product.displayName, kind: kind), product)
        onStockChanged(product)
    }

    private func show(_ next: Step) {
        withAnimation(.smooth) { step = next }
    }

    /// Opening happens on Productos (its navigation), so the sheet closes.
    private func open(_ product: Product) {
        onOpen(product)
        dismiss()
    }

    /// The simulator has no camera: CodeScanner's simulated scan sends this code.
    /// Set it with `xcrun simctl spawn booted defaults write <bundle id> simScanCode <code>`.
    /// Sueltos' scanner uses it too.
    static var simulatedCode: String {
        #if DEBUG
        UserDefaults.standard.string(forKey: "simScanCode") ?? ""
        #else
        ""
        #endif
    }
}

private extension FarmaciaKit.ScanMode {
    var title: String {
        switch self {
        case .consult: "Consultar"
        case .receive: "Recibir"
        case .count: "Contar"
        }
    }
}

// MARK: - Recently Saved

/// The last receive or count, under the viewfinder; tapping it opens the product
/// to check or correct it.
private struct RecentSaveStrip: View {
    let text: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            Label {
                Text(text)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tone.positive.color)
            }
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
                .background(.regularMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .padding(.bottom, DS.Spacing.xl)
        .padding(.horizontal)
        .accessibilityHint("Abre el producto")
        .accessibilityInputLabels(["Último guardado", "Abrir producto"])
    }
}

// MARK: - Candidates

/// Several products match the scanned code: pick one, or create a new one.
private struct BarcodeCandidatesList: View {
    let code: String
    let candidates: [Product]
    let onSelect: (Product) -> Void
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { product in
                        Button {
                            onSelect(product)
                        } label: {
                            HStack(spacing: DS.Spacing.m) {
                                Image(systemName: "shippingbox.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    Text(product.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let sku = product.sku {
                                        Text("SKU: \(sku)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                                    if let price = product.formattedPrice {
                                        Text(price)
                                            .font(.subheadline)
                                            .bold()
                                    }
                                    if let stock = product.totalInventory {
                                        Text("\(stock) uds")
                                            .font(.caption)
                                            .foregroundStyle(stock > 0 ? Color.secondary : Tone.critical.color)
                                    }
                                }
                            }
                            .padding(.vertical, DS.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Resultados para \"\(code)\"")
                }

                Section {
                    Button {
                        onCreate()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text("Crear producto nuevo")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("SKU: \(code)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Tone.positive.color)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Seleccionar Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
            }
        }
    }
}
