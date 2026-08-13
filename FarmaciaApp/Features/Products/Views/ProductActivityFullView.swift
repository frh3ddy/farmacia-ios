import SwiftUI

// MARK: - Product Activity Full View (all history for a product)

struct ProductActivityFullView: View {
    let product: Product
    let recepciones: [InventoryReceiving]
    let ajustes: [InventoryAdjustment]
    
    @State private var selectedSegment: ActivitySegment = .all
    
    enum ActivitySegment: String, CaseIterable {
        case all = "Todos"
        case recepciones = "Recepciones"
        case ajustes = "Ajustes"
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
                    
                case .recepciones:
                    if recepciones.isEmpty {
                        emptyState("Sin recepciones registradas")
                    } else {
                        ForEach(recepciones) { receiving in
                            ReceivingRow(receiving: receiving)
                        }
                    }
                    
                case .ajustes:
                    if ajustes.isEmpty {
                        emptyState("Sin ajustes registrados")
                    } else {
                        ForEach(ajustes) { adjustment in
                            AdjustmentRow(adjustment: adjustment)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("\(product.displayName) Activity")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var combinedItems: [ProductActivityItem] {
        var items: [ProductActivityItem] = []
        
        for r in recepciones {
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
        
        for a in ajustes {
            let displayQty = a.type.isNegative ? -abs(a.quantity) : a.quantity
            items.append(ProductActivityItem(
                id: "adj-\(a.id)",
                kind: .adjustment(a.type),
                title: "\(a.type.displayName)",
                subtitle: a.reason ?? a.notes ?? a.adjustedAt.formatted(date: .abbreviated, time: .shortened),
                date: a.adjustedAt,
                quantity: displayQty,
                icon: a.type.icon,
                iconColor: a.type.isPositive ? .green : (a.type.isNegative ? .red : .orange)
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

