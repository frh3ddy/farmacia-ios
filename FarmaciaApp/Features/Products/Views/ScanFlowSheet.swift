import SwiftUI
import FarmaciaKit
import CodeScanner

// MARK: - Scan Flow Sheet
//
// Scanning a barcode on Productos, as one sheet: scanner → (several matches)
// a list to choose from → (no match) Nuevo Producto with the code as SKU. Each
// step replaces the sheet's content with a slide-in, so there's no closing one
// sheet and opening the next (that handoff lost the prefilled SKU on the first
// try and needed a pending-code + onDismiss workaround). A single match closes
// the sheet and opens the product on Productos.
// Steps are swapped, not pushed: Nuevo Producto has its own NavigationStack,
// and its Cancelar/save already close "the sheet" — the whole flow.

/// What a scanned code resolves to (ProductsView looks it up: loaded products,
/// the on-device cache, then the server — FarmaciaKit `BarcodeLookup`).
enum ScanOutcome {
    case open(Product)
    case choose([Product])
    case create
}

struct ScanFlowSheet: View {
    let lookup: (String) async -> ScanOutcome
    let onOpen: (Product) -> Void
    /// A product created from an unknown code (Nuevo Producto).
    let onCreated: (Product) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .scan
    @State private var isLookingUp = false

    private enum Step: Equatable {
        case scan
        case choose(code: String, candidates: [Product])
        case create(code: String)
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
                    onSelect: open,
                    onCreate: { show(.create(code: code)) }
                )
                .transition(.push(from: .trailing))
            case .create(let code):
                CreateProductView(prefillSku: code, onCreated: onCreated)
                    .transition(.push(from: .trailing))
            }
        }
    }

    private var scanner: some View {
        NavigationStack {
            CodeScannerView(
                codeTypes: [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .qr],
                scanMode: .once,
                showViewfinder: true,
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
                    open(product)
                case .choose(let candidates):
                    show(.choose(code: code, candidates: candidates))
                case .create:
                    show(.create(code: code))
                }
            }
        case .failure:
            dismiss()
        }
    }

    private func show(_ next: Step) {
        withAnimation(.smooth) { step = next }
    }

    /// Opening happens on Productos (its navigation), so the sheet closes.
    private func open(_ product: Product) {
        onOpen(product)
        dismiss()
    }
}

// MARK: - Candidates

/// Several products match the scanned code: pick one, or create a new one.
private struct BarcodeCandidatesList: View {
    let code: String
    let candidates: [Product]
    let onSelect: (Product) -> Void
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

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
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
