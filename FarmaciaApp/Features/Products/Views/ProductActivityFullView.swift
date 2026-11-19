import SwiftUI
import FarmaciaKit

// MARK: - Product Activity Full View (all history for a product)

struct ProductActivityFullView: View {
    let product: Product
    let receivings: [InventoryReceiving]
    let adjustments: [InventoryAdjustment]
    /// Owner-only Square sync retries; each returns the message to show. Nil hides Reintentar.
    var retryReceiving: ((InventoryReceiving) async -> String)? = nil
    var retryAdjustment: ((InventoryAdjustment) async -> String)? = nil
    /// Owner-only Corregir costo: nil on success, else the message to show. Nil hides the button.
    var fixReceivingCost: ((InventoryReceiving, Decimal) async -> String?)? = nil

    @State private var selectedSegment: ActivitySegment = .all
    @State private var syncRetryMessage = ""
    @State private var showSyncRetryMessage = false
    @State private var costFixReceiving: InventoryReceiving?

    enum ActivitySegment: String, CaseIterable {
        case all = "Todos"
        case receivings = "Recepciones"
        case adjustments = "Ajustes"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Actividad", selection: $selectedSegment) {
                ForEach(ActivitySegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                switch selectedSegment {
                case .all:
                    let allItems = combinedItems
                    if allItems.isEmpty {
                        emptyState("Sin actividad registrada")
                    } else {
                        ForEach(allItems) { item in
                            ActivityFullRow(item: item)
                        }
                    }
                    
                case .receivings:
                    if receivings.isEmpty {
                        emptyState("Sin recepciones registradas")
                    } else {
                        ForEach(receivings) { receiving in
                            ReceivingRow(
                                receiving: receiving,
                                onRetrySync: retryReceiving.map { retry in { await showRetryResult(retry(receiving)) } },
                                onFixCost: fixReceivingCost.map { _ in { costFixReceiving = receiving } }
                            )
                        }
                    }

                case .adjustments:
                    if adjustments.isEmpty {
                        emptyState("Sin ajustes registrados")
                    } else {
                        ForEach(adjustments) { adjustment in
                            AdjustmentRow(
                                adjustment: adjustment,
                                onRetrySync: retryAdjustment.map { retry in { await showRetryResult(retry(adjustment)) } }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheet(item: $costFixReceiving) { receiving in
                if let fixReceivingCost {
                    FixReceivingCostView(receiving: receiving) { cost in
                        await fixReceivingCost(receiving, cost)
                    }
                }
            }
        }
        .navigationTitle("\(product.displayName) Activity")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Square", isPresented: $showSyncRetryMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(syncRetryMessage)
        }
    }

    private func showRetryResult(_ message: String) {
        syncRetryMessage = message
        showSyncRetryMessage = true
    }
    
    private var combinedItems: [ProductActivityItem] {
        var items: [ProductActivityItem] = []
        
        for r in receivings {
            items.append(ProductActivityItem(
                id: "recv-\(r.id)",
                kind: .receiving,
                title: "Recibido \(r.quantity) uds",
                subtitle: r.supplier?.name ?? r.invoiceNumber.map { "Factura: \($0)" } ?? r.formattedDate,
                date: r.receivedAt,
                quantity: r.quantity,
                icon: "arrow.down.circle.fill",
                iconColor: .blue
            ))
        }

        for a in adjustments {
            items.append(ProductActivityItem(
                id: "adj-\(a.id)",
                kind: .adjustment(a.type),
                title: "\(a.type.displayName)",
                subtitle: a.reason ?? a.notes ?? a.adjustedAt.formatted(date: .abbreviated, time: .shortened),
                date: a.adjustedAt,
                quantity: a.quantity,
                icon: a.type.icon,
                iconColor: StockChange(quantity: a.quantity).tone.color
            ))
        }
        
        return items.sorted { $0.date > $1.date }
    }
    
    @ViewBuilder
    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowBackground(Color.clear)
    }
}

// MARK: - Activity Full Row (used in the full activity list)

struct ActivityFullRow: View {
    let item: ProductActivityItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundStyle(item.iconColor)
                .frame(width: 32, height: 32)
                .background(item.iconColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(item.quantityDisplay)
                .font(.headline)
                .foregroundStyle(item.quantityColor)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Corregir costo (owner): a receiving saved with the wrong unit cost

struct FixReceivingCostView: View {
    let receiving: InventoryReceiving
    /// nil on success, else the message to show (a 409 refusal as the API wrote it).
    let save: (Decimal) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var costText = ""
    @State private var isConfirming = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var newCost: Decimal? { ReceivingCostFix.cost(from: costText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Recibido", value: receiving.formattedDate)
                    LabeledContent("Cantidad", value: "\(receiving.quantity) uds")
                    if let supplier = receiving.supplier?.name {
                        LabeledContent("Proveedor", value: supplier)
                    }
                    LabeledContent("Costo actual", value: ReportFormat.currency(receiving.unitCost))
                }
                Section {
                    TextField("Costo nuevo por unidad", text: $costText)
                        .keyboardType(.decimalPad)
                    if let newCost, ReceivingCostFix.canSave(newCost: newCost, oldCost: receiving.unitCost) {
                        Text(ReceivingCostFix.comparison(oldCost: receiving.unitCost, newCost: newCost))
                            .font(.headline)
                            .monospacedDigit()
                    }
                } footer: {
                    Text("Recalcula esta recepción, su lote, las ventas y mermas que salieron de ella y, si es la más reciente del proveedor, su costo actual.")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Corregir costo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Guardar") { isConfirming = true }
                            .disabled(!ReceivingCostFix.canSave(newCost: newCost, oldCost: receiving.unitCost))
                    }
                }
            }
            .confirmationDialog("¿Corregir el costo?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Corregir costo") { Task { await submit() } }
            } message: {
                if let newCost {
                    Text("\(ReceivingCostFix.comparison(oldCost: receiving.unitCost, newCost: newCost)) por unidad, \(receiving.quantity) uds")
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func submit() async {
        guard let newCost else { return }
        isSaving = true
        errorMessage = await save(newCost)
        isSaving = false
        if errorMessage == nil { dismiss() }
    }
}
