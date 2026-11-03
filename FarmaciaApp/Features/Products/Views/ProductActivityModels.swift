import SwiftUI
import FarmaciaKit

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
        StockChange(quantity: quantity).tone.color
    }
}

// MARK: - Product Activity ViewModel

@MainActor
class ProductActivityViewModel: ObservableObject {
    @Published var receivings: [InventoryReceiving] = []
    @Published var adjustments: [InventoryAdjustment] = []
    @Published var isLoading = false

    private let apiClient = APIClient.shared

    /// Combined and chronologically sorted activity for the product
    var combinedActivity: [ProductActivityItem] {
        var items: [ProductActivityItem] = []

        // Convert receivings
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
        
        // Convert adjustments
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
        
        // Sort by date, newest first
        return items.sorted { $0.date > $1.date }
    }
    
    func loadActivity(productId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        guard !Task.isCancelled else { return }
        
        // Load both in parallel
        async let receivingsResult: () = loadReceivings(productId: productId)
        async let adjustmentsResult: () = loadAdjustments(productId: productId)

        _ = await (receivingsResult, adjustmentsResult)
    }

    private func loadReceivings(productId: String) async {
        do {
            let response: ReceivingListResponse = try await apiClient.request(
                endpoint: .listReceivingsByProduct(productId: productId)
            )
            receivings = response.data
        } catch {
            // Silent fail — receivings are supplementary
            print("Failed to load product receivings: \(error)")
        }
    }

    private func loadAdjustments(productId: String) async {
        do {
            let response: AdjustmentListResponse = try await apiClient.request(
                endpoint: .adjustmentsByProduct(productId: productId)
            )
            adjustments = response.data
        } catch {
            // Silent fail — adjustments are supplementary
            print("Failed to load product adjustments: \(error)")
        }
    }
}
