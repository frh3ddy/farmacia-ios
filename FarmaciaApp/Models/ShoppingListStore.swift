import Foundation

// MARK: - Shopping List Store
// Local JSON file persistence for shopping lists.
// Each list is stored as an individual JSON file in Documents/ShoppingLists/.
// Thread-safe via @MainActor — all UI calls happen on main thread.

@MainActor
class ShoppingListStore: ObservableObject {
    static let shared = ShoppingListStore()
    
    @Published var lists: [ShoppingList] = []
    
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var storeDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("ShoppingLists", isDirectory: true)
    }
    
    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        ensureDirectoryExists()
        loadAll()
    }
    
    // MARK: - Directory Management
    
    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storeDirectory.path) {
            try? fileManager.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - File Paths
    
    private func fileURL(for listId: UUID) -> URL {
        storeDirectory.appendingPathComponent("\(listId.uuidString).json")
    }
    
    // MARK: - Load
    
    func loadAll() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: storeDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            lists = []
            return
        }
        
        var loaded: [ShoppingList] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let list = try? decoder.decode(ShoppingList.self, from: data) {
                loaded.append(list)
            }
        }
        
        // Sort: active lists first (draft, ready, partiallyReceived), then completed. Within groups, most recent first.
        lists = loaded.sorted { a, b in
            let aActive = a.status != .completed
            let bActive = b.status != .completed
            if aActive != bActive { return aActive }
            return a.updatedAt > b.updatedAt
        }
    }
    
    // MARK: - Save
    
    func save(_ list: ShoppingList) {
        do {
            let data = try encoder.encode(list)
            try data.write(to: fileURL(for: list.id), options: .atomic)
            
            // Update in-memory list
            if let idx = lists.firstIndex(where: { $0.id == list.id }) {
                lists[idx] = list
            } else {
                lists.insert(list, at: 0)
            }
            
            // Re-sort
            sortLists()
        } catch {
            print("ShoppingListStore: Failed to save list \(list.id): \(error)")
        }
    }
    
    // MARK: - Create
    
    @discardableResult
    func createList(
        name: String,
        supplierId: String? = nil,
        supplierName: String? = nil,
        locationId: String? = nil,
        locationName: String? = nil,
        notes: String? = nil
    ) -> ShoppingList {
        let list = ShoppingList(
            name: name,
            supplierId: supplierId,
            supplierName: supplierName,
            locationId: locationId,
            locationName: locationName,
            notes: notes
        )
        save(list)
        return list
    }
    
    // MARK: - Update
    
    func update(_ list: ShoppingList) {
        var updated = list
        updated.updatedAt = Date()
        save(updated)
    }
    
    func addItem(to listId: UUID, item: ShoppingListItem) {
        guard var list = lists.first(where: { $0.id == listId }) else { return }
        list.addItem(item)
        save(list)
    }
    
    func removeItems(from listId: UUID, at offsets: IndexSet) {
        guard var list = lists.first(where: { $0.id == listId }) else { return }
        list.removeItems(at: offsets)
        save(list)
    }
    
    func updateItem(in listId: UUID, itemId: UUID, update: (inout ShoppingListItem) -> Void) {
        guard var list = lists.first(where: { $0.id == listId }) else { return }
        if let idx = list.items.firstIndex(where: { $0.id == itemId }) {
            update(&list.items[idx])
            list.updatedAt = Date()
            save(list)
        }
    }
    
    func markItemReceived(listId: UUID, itemId: UUID, receivedQuantity: Int) {
        guard var list = lists.first(where: { $0.id == listId }) else { return }
        list.markItemReceived(itemId: itemId, receivedQuantity: receivedQuantity)
        save(list)
    }
    
    func markReady(_ listId: UUID) {
        guard var list = lists.first(where: { $0.id == listId }) else { return }
        list.markReady()
        save(list)
    }
    
    func reopenAsDraft(_ listId: UUID) {
        guard var list = lists.first(where: { $0.id == listId }) else { return }
        list.reopenAsDraft()
        save(list)
    }
    
    // MARK: - Delete
    
    func delete(_ listId: UUID) {
        try? fileManager.removeItem(at: fileURL(for: listId))
        lists.removeAll { $0.id == listId }
    }
    
    func deleteCompleted() {
        let completed = lists.filter { $0.status == .completed }
        for list in completed {
            delete(list.id)
        }
    }
    
    // MARK: - Duplicate
    
    @discardableResult
    func duplicate(_ listId: UUID, newName: String) -> ShoppingList? {
        guard let original = lists.first(where: { $0.id == listId }) else { return nil }
        
        var newList = ShoppingList(
            name: newName,
            supplierId: original.supplierId,
            supplierName: original.supplierName,
            locationId: original.locationId,
            locationName: original.locationName,
            notes: original.notes
        )
        
        // Copy items but reset received state
        newList.items = original.items.map { item in
            ShoppingListItem(
                productId: item.productId,
                productName: item.productName,
                sku: item.sku,
                plannedQuantity: item.plannedQuantity,
                unitCost: item.unitCost,
                previousCost: item.previousCost
            )
        }
        
        save(newList)
        return newList
    }
    
    // MARK: - Query Helpers
    
    var activeLists: [ShoppingList] {
        lists.filter { $0.status != .completed }
    }
    
    var draftLists: [ShoppingList] {
        lists.filter { $0.status == .draft }
    }
    
    var completedLists: [ShoppingList] {
        lists.filter { $0.status == .completed }
    }
    
    var totalPendingItems: Int {
        activeLists.reduce(0) { $0 + $1.pendingCount }
    }
    
    func list(for id: UUID) -> ShoppingList? {
        lists.first { $0.id == id }
    }
    
    // MARK: - Private
    
    private func sortLists() {
        lists.sort { a, b in
            let aActive = a.status != .completed
            let bActive = b.status != .completed
            if aActive != bActive { return aActive }
            return a.updatedAt > b.updatedAt
        }
    }
}
