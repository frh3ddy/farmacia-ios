import SwiftUI

// MARK: - Product Activity Item (unified timeline model)

struct ProductActivityItem: Identifiable {
    enum ActivityKind {
        case receiving
        case adjustment(AdjustmentType)
    }
    
    let id: String
    let kind: ActivityKind
    let title: String
    let subtitle: String
    let date: Date
    let quantity: Int
    let icon: String
    let iconColor: Color
    
    var quantityDisplay: String {
        if quantity > 0 {
            return "+\(quantity)"
        }
        return "\(quantity)"
    }
    
    var quantityColor: Color {
        quantity > 0 ? .green : .red
    }
}

// MARK: - Product Activity ViewModel

@MainActor
class ProductActivityViewModel: ObservableObject {
    @Published var recepciones: [InventoryReceiving] = []
    @Published var ajustes: [InventoryAdjustment] = []
    @Published var isLoading = false
    
    private let apiClient = APIClient.shared
    
    /// Combined and chronologically sorted activity for the product
    var combinedActivity: [ProductActivityItem] {
        var items: [ProductActivityItem] = []
        
        // Convert recepciones
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
        
        // Convert ajustes
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
        
        // Sort by date, newest first
        return items.sorted { $0.date > $1.date }
    }
    
    func loadActivity(productId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        guard !Task.isCancelled else { return }
        
        // Load both in parallel
        async let recepcionesResult: () = loadReceivings(productId: productId)
        async let ajustesResult: () = loadAdjustments(productId: productId)
        
        _ = await (recepcionesResult, ajustesResult)
    }
    
    private func loadReceivings(productId: String) async {
        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByProduct(productId: productId)
            )
            recepciones = response.data
        } catch {
            // Silent fail — recepciones are supplementary
            print("Failed to load product recepciones: \(error)")
        }
    }
    
    private func loadAdjustments(productId: String) async {
        do {
            let response: AdjustmentListResponse = try await apiClient.request(
                endpoint: .ajustesByProduct(productId: productId)
            )
            ajustes = response.data
        } catch {
            // Silent fail — ajustes are supplementary
            print("Failed to load product ajustes: \(error)")
        }
    }
}
