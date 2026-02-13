import Foundation

// MARK: - Shopping List Models
// Local-first shopping list for planning purchases before receiving into inventory.
// Persisted as JSON files via ShoppingListStore — no backend dependency.

// MARK: - Shopping List Status

enum ShoppingListStatus: String, Codable, CaseIterable {
    case draft              // Still editing — adding/removing items
    case ready              // Finalized, ready to take to supplier
    case partiallyReceived  // Some items received into inventory
    case completed          // All items received
    
    var label: String {
        switch self {
        case .draft: return "Draft"
        case .ready: return "Ready"
        case .partiallyReceived: return "Partially Received"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "pencil.circle"
        case .ready: return "checkmark.circle"
        case .partiallyReceived: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.seal.fill"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .ready: return "blue"
        case .partiallyReceived: return "orange"
        case .completed: return "green"
        }
    }
}

// MARK: - Shopping List Item

struct ShoppingListItem: Codable, Identifiable {
    let id: UUID
    var productId: String
    var productName: String
    var sku: String?
    
    var plannedQuantity: Int          // What we intend to buy
    var receivedQuantity: Int         // What we actually received (0 until receive)
    var unitCost: Double              // Expected / actual cost
    var previousCost: Double?         // Last known cost for comparison
    
    var batchNumber: String?
    var expiryDate: Date?
    var notes: String?
    
    var isReceived: Bool              // Line-item level receive flag
    
    // MARK: Computed
    
    var plannedTotal: Double { Double(plannedQuantity) * unitCost }
    var receivedTotal: Double { Double(receivedQuantity) * unitCost }
    var pendingQuantity: Int { max(0, plannedQuantity - receivedQuantity) }
    
    var formattedUnitCost: String {
        String(format: "$%.2f", unitCost)
    }
    
    var formattedPlannedTotal: String {
        String(format: "$%.2f", plannedTotal)
    }
    
    var costChanged: Bool {
        guard let prev = previousCost else { return false }
        return abs(prev - unitCost) > 0.001
    }
    
    var costChangeDescription: String? {
        guard let prev = previousCost, costChanged else { return nil }
        let diff = unitCost - prev
        let pct = (diff / prev) * 100
        let arrow = diff > 0 ? "↑" : "↓"
        return String(format: "%@ $%.2f → $%.2f (%+.0f%%)", arrow, prev, unitCost, pct)
    }
    
    var formattedExpiryDate: String? {
        guard let date = expiryDate else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    // MARK: Init
    
    init(
        productId: String,
        productName: String,
        sku: String? = nil,
        plannedQuantity: Int = 1,
        unitCost: Double,
        previousCost: Double? = nil,
        batchNumber: String? = nil,
        expiryDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.productId = productId
        self.productName = productName
        self.sku = sku
        self.plannedQuantity = plannedQuantity
        self.receivedQuantity = 0
        self.unitCost = unitCost
        self.previousCost = previousCost
        self.batchNumber = batchNumber
        self.expiryDate = expiryDate
        self.notes = notes
        self.isReceived = false
    }
}

// MARK: - Shopping List

struct ShoppingList: Codable, Identifiable {
    let id: UUID
    var name: String
    var supplierId: String?           // Optional until receive
    var supplierName: String?
    var status: ShoppingListStatus
    var items: [ShoppingListItem]
    var invoiceNumber: String?
    var notes: String?
    let createdAt: Date
    var updatedAt: Date
    var locationId: String?           // Target location
    var locationName: String?
    
    // MARK: Computed
    
    var itemCount: Int { items.count }
    var receivedCount: Int { items.filter(\.isReceived).count }
    var pendingCount: Int { items.filter { !$0.isReceived }.count }
    
    var plannedTotal: Double {
        items.reduce(0) { $0 + $1.plannedTotal }
    }
    
    var receivedTotal: Double {
        items.filter(\.isReceived).reduce(0) { $0 + $1.receivedTotal }
    }
    
    var formattedPlannedTotal: String {
        String(format: "$%.2f", plannedTotal)
    }
    
    var formattedReceivedTotal: String {
        String(format: "$%.2f", receivedTotal)
    }
    
    var isEditable: Bool {
        status == .draft || status == .ready
    }
    
    var canReceive: Bool {
        !items.isEmpty && status != .completed
    }
    
    var hasUnreceivedItems: Bool {
        items.contains { !$0.isReceived }
    }
    
    var formattedDate: String {
        updatedAt.formatted(date: .abbreviated, time: .omitted)
    }
    
    var itemsWithCostChanges: [ShoppingListItem] {
        items.filter(\.costChanged)
    }
    
    // MARK: Init
    
    init(
        name: String,
        supplierId: String? = nil,
        supplierName: String? = nil,
        locationId: String? = nil,
        locationName: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.supplierId = supplierId
        self.supplierName = supplierName
        self.status = .draft
        self.items = []
        self.invoiceNumber = nil
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.locationId = locationId
        self.locationName = locationName
    }
    
    // MARK: Mutations
    
    mutating func addItem(_ item: ShoppingListItem) {
        // If product already exists, increment quantity
        if let idx = items.firstIndex(where: { $0.productId == item.productId }) {
            items[idx].plannedQuantity += item.plannedQuantity
        } else {
            items.append(item)
        }
        updatedAt = Date()
    }
    
    mutating func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        updatedAt = Date()
    }
    
    mutating func removeItem(productId: String) {
        items.removeAll { $0.productId == productId }
        updatedAt = Date()
    }
    
    mutating func markItemReceived(itemId: UUID, receivedQuantity: Int) {
        if let idx = items.firstIndex(where: { $0.id == itemId }) {
            items[idx].isReceived = true
            items[idx].receivedQuantity = receivedQuantity
        }
        updateStatusAfterReceive()
        updatedAt = Date()
    }
    
    mutating func markReady() {
        if status == .draft { status = .ready }
        updatedAt = Date()
    }
    
    mutating func reopenAsDraft() {
        if status == .ready { status = .draft }
        updatedAt = Date()
    }
    
    private mutating func updateStatusAfterReceive() {
        let allReceived = items.allSatisfy(\.isReceived)
        let someReceived = items.contains(where: \.isReceived)
        
        if allReceived {
            status = .completed
        } else if someReceived {
            status = .partiallyReceived
        }
    }
}
