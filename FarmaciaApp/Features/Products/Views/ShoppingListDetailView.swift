import SwiftUI

// MARK: - Shopping List Detail View
// The main editing/viewing screen for a shopping list.
// Shows items with column-aligned rows, cost comparison, status management,
// and actions to add items, assign supplier, receive, duplicate.
//
// Tap a row → opens EditItemSheet (no more inline expand/collapse).

struct ShoppingListDetailView: View {
    let listId: UUID
    @ObservedObject var store: ShoppingListStore
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showAddItems = false
    @State private var showReceiveFlow = false
    @State private var showSupplierPicker = false
    @State private var showEditName = false
    @State private var showDuplicateAlert = false
    @State private var showDeleteAlert = false
    @State private var showCostRefreshAlert = false
    @State private var editingItem: ShoppingListItem?   // drives the edit sheet
    @State private var suppliers: [Supplier] = []
    @State private var isLoadingSuppliers = false
    @State private var isRefreshingCosts = false
    @State private var editedName = ""
    @State private var selectedSupplier: Supplier?
    @State private var costRefreshResult: CostRefreshResult?
    
    private let apiClient = APIClient.shared
    
    private var list: ShoppingList? {
        store.list(for: listId)
    }
    
    var body: some View {
        Group {
            if let list = list {
                listDetail(list)
            } else {
                VStack {
                    Text("List not found")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(list?.name ?? "Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let list = list {
                    Menu {
                        if list.isEditable {
                            Button {
                                editedName = list.name
                                showEditName = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                        }
                        
                        Button {
                            showDuplicateAlert = true
                        } label: {
                            Label("Duplicate List", systemImage: "doc.on.doc")
                        }
                        
                        // Manual cost refresh
                        if list.isEditable && list.supplierId != nil && !list.items.isEmpty {
                            Button {
                                Task { await refreshCostsFromSupplier() }
                            } label: {
                                Label("Refresh Costs", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        
                        Divider()
                        
                        if list.status == .draft {
                            Button {
                                store.markReady(listId)
                            } label: {
                                Label("Mark as Ready", systemImage: "checkmark.circle")
                            }
                        } else if list.status == .ready {
                            Button {
                                store.reopenAsDraft(listId)
                            } label: {
                                Label("Reopen as Draft", systemImage: "pencil.circle")
                            }
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Eliminar Lista", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddItems) {
            if let list = list {
                AddItemsSheet(
                    listId: listId,
                    store: store,
                    supplierId: list.supplierId,
                    locationId: authManager.currentLocation?.id
                )
            }
        }
        .sheet(isPresented: $showReceiveFlow) {
            if list != nil {
                ReceiveFlowView(
                    listId: listId,
                    store: store
                )
            }
        }
        .sheet(isPresented: $showSupplierPicker) {
            SupplierPickerSheet(
                suppliers: suppliers,
                isLoading: isLoadingSuppliers,
                selected: $selectedSupplier
            )
        }
        .sheet(item: $editingItem) { item in
            EditItemSheet(item: item) { updated in
                store.updateItem(in: listId, itemId: item.id) { existing in
                    existing.plannedQuantity = updated.plannedQuantity
                    existing.unitCost = updated.unitCost
                    existing.batchNumber = updated.batchNumber
                    existing.expiryDate = updated.expiryDate
                    existing.notes = updated.notes
                }
            }
        }
        .onChange(of: selectedSupplier) { oldValue, newValue in
            if let supplier = newValue {
                assignSupplier(supplier)
            }
        }
        .alert("Rename List", isPresented: $showEditName) {
            TextField("List name", text: $editedName)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                if var updated = list {
                    updated.name = editedName.trimmingCharacters(in: .whitespaces)
                    store.update(updated)
                }
            }
        }
        .alert("Duplicate List?", isPresented: $showDuplicateAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Duplicate") {
                if let list = list {
                    store.duplicate(listId, newName: "\(list.name) (copy)")
                }
            }
        } message: {
            Text("Creates a new draft with the same items and quantities.")
        }
        .alert("Delete List?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive) {
                store.delete(listId)
                dismiss()
            }
        } message: {
            Text("This will permanently delete this shopping list.")
        }
        .alert("Update Costs?", isPresented: $showCostRefreshAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Update Costs") {
                Task { await refreshCostsFromSupplier() }
            }
        } message: {
            if let supplierName = list?.supplierName {
                Text("Update item costs from \(supplierName)'s catalog? Items with price changes will be flagged.")
            } else {
                Text("Update item costs from the supplier catalog?")
            }
        }
        .task {
            await loadSuppliers()
        }
    }
    
    // MARK: - List Detail Content
    
    @ViewBuilder
    private func listDetail(_ list: ShoppingList) -> some View {
        VStack(spacing: 0) {
            List {
                // Status & Supplier header
                headerSection(list)
                
                // Cost refresh in-progress indicator
                if isRefreshingCosts {
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Refreshing costs from supplier catalog...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Cost refresh result banner
                if let result = costRefreshResult {
                    costRefreshResultSection(result)
                }
                
                // Cost changes alert
                if !list.itemsWithCostChanges.isEmpty {
                    costChangesSection(list)
                }
                
                // Items
                if list.items.isEmpty {
                    Section {
                        emptyItemsView
                    }
                } else {
                    itemsSection(list)
                }
                
                // Notes & Invoice
                detailsSection(list)
            }
            .listStyle(.insetGrouped)
            
            // Bottom action bar
            bottomBar(list)
        }
    }
    
    // MARK: - Header Section
    
    private func headerSection(_ list: ShoppingList) -> some View {
        Section {
            // Status row
            HStack {
                Image(systemName: list.status.icon)
                    .foregroundColor(statusColor(list.status))
                Text(list.status.label)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(list.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Supplier row
            Button {
                if list.isEditable {
                    selectedSupplier = nil
                    showSupplierPicker = true
                }
            } label: {
                HStack {
                    Image(systemName: "building.2")
                        .foregroundColor(.secondary)
                    
                    if let name = list.supplierName {
                        Text(name)
                            .foregroundColor(.primary)
                    } else {
                        Text("No supplier assigned")
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    if list.isEditable {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!list.isEditable)
            
            // Summary row
            HStack {
                summaryPill(
                    icon: "number",
                    value: "\(list.itemCount)",
                    label: "artículos"
                )
                
                Spacer()
                
                if list.status == .partiallyReceived {
                    summaryPill(
                        icon: "checkmark.circle",
                        value: "\(list.receivedCount)/\(list.itemCount)",
                        label: "received",
                        color: .green
                    )
                    
                    Spacer()
                }
                
                summaryPill(
                    icon: "dollarsign.circle",
                    value: list.formattedPlannedTotal,
                    label: "total",
                    color: .blue
                )
            }
            .padding(.vertical, 4)
        }
    }
    
    private func summaryPill(icon: String, value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Cost Changes Alert
    
    private func costChangesSection(_ list: ShoppingList) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Cost Changes Detected")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                ForEach(list.itemsWithCostChanges) { item in
                    if let change = item.costChangeDescription {
                        HStack {
                            Text(item.productName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(change)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Cost Refresh Result Section
    
    private func costRefreshResultSection(_ result: CostRefreshResult) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: result.updatedCount > 0 ? "arrow.triangle.2.circlepath.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(result.updatedCount > 0 ? .blue : .green)
                    Text(result.updatedCount > 0 ? "\(result.updatedCount) Cost(s) Updated" : "All Costs Current")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        costRefreshResult = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if !result.changes.isEmpty {
                    ForEach(result.changes, id: \.productName) { change in
                        HStack {
                            Text(change.productName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(change.description)
                                .font(.caption)
                                .foregroundColor(change.isIncrease ? .red : .green)
                        }
                    }
                }
                
                if result.notFoundCount > 0 {
                    Text("\(result.notFoundCount) item(s) not in supplier catalog")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Items Section
    
    private func itemsSection(_ list: ShoppingList) -> some View {
        Section {
            ForEach(list.items) { item in
                Button {
                    if list.isEditable && !item.isReceived {
                        editingItem = item
                    }
                } label: {
                    ShoppingListItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                if list.isEditable {
                    store.removeItems(from: listId, at: offsets)
                }
            }
        } header: {
            HStack {
                Text("Items (\(list.itemCount))")
                Spacer()
                if list.isEditable {
                    Button {
                        showAddItems = true
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                            Text("Agregar")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty Items
    
    private var emptyItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No items yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showAddItems = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Agregar Artículos")
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Details Section
    
    private func detailsSection(_ list: ShoppingList) -> some View {
        Section {
            if list.isEditable {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                    TextField("Invoice Number", text: Binding(
                        get: { list.invoiceNumber ?? "" },
                        set: { newValue in
                            if var updated = self.list {
                                updated.invoiceNumber = newValue.isEmpty ? nil : newValue
                                store.update(updated)
                            }
                        }
                    ))
                    .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                    TextField("Notas", text: Binding(
                        get: { list.notes ?? "" },
                        set: { newValue in
                            if var updated = self.list {
                                updated.notes = newValue.isEmpty ? nil : newValue
                                store.update(updated)
                            }
                        }
                    ))
                    .font(.subheadline)
                }
            } else {
                if let invoice = list.invoiceNumber, !invoice.isEmpty {
                    HStack {
                        Text("Invoice")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(invoice)
                            .font(.subheadline)
                    }
                }
                if let notes = list.notes, !notes.isEmpty {
                    HStack {
                        Text("Notas")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Detalles")
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private func bottomBar(_ list: ShoppingList) -> some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack(spacing: 12) {
                if list.isEditable && !list.items.isEmpty {
                    Button {
                        showAddItems = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Agregar Artículos")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                
                if list.canReceive {
                    Button {
                        showReceiveFlow = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text(receiveButtonLabel(list))
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(list.supplierId != nil ? Color.blue : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(list.supplierId == nil)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if list.canReceive && list.supplierId == nil {
                Text("Assign a supplier before receiving items")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.bottom, 4)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func receiveButtonLabel(_ list: ShoppingList) -> String {
        let count = list.pendingCount
        if list.status == .partiallyReceived {
            return "Receive \(count) Remaining"
        }
        return "Receive \(count) Items"
    }
    
    // MARK: - Helpers
    
    private func statusColor(_ status: ShoppingListStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .ready: return .blue
        case .partiallyReceived: return .orange
        case .completed: return .green
        }
    }
    
    private func assignSupplier(_ supplier: Supplier) {
        guard var updated = list else { return }
        updated.supplierId = supplier.id
        updated.supplierName = supplier.name
        store.update(updated)
        
        // Offer to refresh costs when supplier is assigned and list has items
        if !updated.items.isEmpty {
            showCostRefreshAlert = true
        }
    }
    
    // MARK: - Cost Refresh from Supplier Catalog
    
    private func refreshCostsFromSupplier() async {
        guard let list = list, let supplierId = list.supplierId else { return }
        
        isRefreshingCosts = true
        costRefreshResult = nil
        defer { isRefreshingCosts = false }
        
        do {
            var queryParams: [String: String] = [:]
            if let locationId = authManager.currentLocation?.id {
                queryParams["locationId"] = locationId
            }
            
            let response: SupplierCatalogResponse = try await apiClient.request(
                endpoint: .supplierCatalog(supplierId: supplierId),
                queryParams: queryParams
            )
            
            let catalogLookup = Dictionary(
                response.products.map { ($0.productId, $0.lastCostDouble) },
                uniquingKeysWith: { first, _ in first }
            )
            
            var updatedCount = 0
            var notFoundCount = 0
            var changes: [CostRefreshChange] = []
            
            for item in list.items where !item.isReceived {
                if let supplierCost = catalogLookup[item.productId] {
                    if abs(supplierCost - item.unitCost) > 0.001 {
                        let oldCost = item.unitCost
                        store.updateItem(in: listId, itemId: item.id) { existing in
                            existing.previousCost = existing.unitCost
                            existing.unitCost = supplierCost
                        }
                        updatedCount += 1
                        let diff = supplierCost - oldCost
                        let pct = oldCost > 0 ? (diff / oldCost) * 100 : 0
                        changes.append(CostRefreshChange(
                            productName: item.productName,
                            oldCost: oldCost,
                            newCost: supplierCost,
                            percentChange: pct,
                            isIncrease: diff > 0
                        ))
                    }
                } else {
                    notFoundCount += 1
                }
            }
            
            costRefreshResult = CostRefreshResult(
                updatedCount: updatedCount,
                notFoundCount: notFoundCount,
                changes: changes
            )
        } catch {
            print("Failed to refresh costs: \(error)")
        }
    }
    
    private func loadSuppliers() async {
        isLoadingSuppliers = true
        defer { isLoadingSuppliers = false }
        
        do {
            let response: SupplierListResponse = try await apiClient.request(
                endpoint: .listSuppliers
            )
            suppliers = response.data.filter { $0.isActive ?? true }
        } catch {
            print("Failed to load suppliers: \(error)")
        }
    }
}

// MARK: - Cost Refresh Models

struct CostRefreshChange {
    let productName: String
    let oldCost: Double
    let newCost: Double
    let percentChange: Double
    let isIncrease: Bool
    
    var description: String {
        let arrow = isIncrease ? "↑" : "↓"
        return String(format: "%@ $%.2f → $%.2f (%+.0f%%)", arrow, oldCost, newCost, percentChange)
    }
}

struct CostRefreshResult {
    let updatedCount: Int
    let notFoundCount: Int
    let changes: [CostRefreshChange]
}

// MARK: - Shopping List Item Row (display-only)
// Tap is handled by the parent via Button wrapper.
// No contentShape/onTapGesture — no hit-test conflicts.

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    
    var body: some View {
        HStack(spacing: 10) {
            // Status icon
            if item.isReceived {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.body)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary.opacity(0.4))
                    .font(.body)
            }
            
            // Product name + metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .strikethrough(item.isReceived, color: .secondary)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    if let sku = item.sku {
                        Text(sku)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let change = item.costChangeDescription {
                        Text(change)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    // Metadata pills inline
                    if let batch = item.batchNumber, !batch.isEmpty {
                        Text("Lot: \(batch)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .cornerRadius(3)
                    }
                    
                    if let expiry = item.formattedExpiryDate {
                        Text("Exp: \(expiry)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .cornerRadius(3)
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            // Qty × Cost = Total (right-aligned column)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.plannedQuantity) × \(item.formattedUnitCost)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(item.formattedPlannedTotal)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                if item.isReceived {
                    Text("Rcvd: \(item.receivedQuantity)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isReceived ? 0.6 : 1.0)
    }
}

// MARK: - Edit Item Sheet
// A focused form for editing a single shopping list item.
// Opens as a half-sheet — no hit-test conflicts with the list.

struct EditItemSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let item: ShoppingListItem
    var onSave: (ShoppingListItem) -> Void
    
    @State private var quantity: Int
    @State private var costText: String
    @State private var batchNumber: String
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date
    @State private var notes: String
    
    init(item: ShoppingListItem, onSave: @escaping (ShoppingListItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _quantity = State(initialValue: item.plannedQuantity)
        _costText = State(initialValue: String(format: "%.2f", item.unitCost))
        _batchNumber = State(initialValue: item.batchNumber ?? "")
        _hasExpiry = State(initialValue: item.expiryDate != nil)
        _expiryDate = State(initialValue: item.expiryDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60))
        _notes = State(initialValue: item.notes ?? "")
    }
    
    private var parsedCost: Double {
        Double(costText) ?? item.unitCost
    }
    
    private var lineTotal: Double {
        Double(quantity) * parsedCost
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Product info (read-only)
                Section {
                    HStack {
                        Text(item.productName)
                            .font(.headline)
                        Spacer()
                        if let sku = item.sku {
                            Text(sku)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let change = item.costChangeDescription {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(change)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // Quantity & Cost
                Section {
                    // Quantity with stepper
                    Stepper(value: $quantity, in: 1...9999) {
                        HStack {
                            Text("Cantidad")
                            Spacer()
                            Text("\(quantity)")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .monospacedDigit()
                        }
                    }
                    
                    // Unit cost
                    HStack {
                        Text("Costo Unitario")
                        Spacer()
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $costText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    // Line total (computed, read-only)
                    HStack {
                        Text("Line Total")
                            .fontWeight(.medium)
                        Spacer()
                        Text(String(format: "$%.2f", lineTotal))
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("Quantity & Cost")
                }
                
                // Batch & Expiry
                Section {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        TextField("Lot / Batch # (optional)", text: $batchNumber)
                    }
                    
                    Toggle(isOn: $hasExpiry) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            Text("Expiry Date")
                        }
                    }
                    
                    if hasExpiry {
                        DatePicker(
                            "Expires",
                            selection: $expiryDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Batch Info")
                }
                
                // Notes
                Section {
                    TextField("Item notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notas")
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func save() {
        var updated = item
        updated.plannedQuantity = max(1, quantity)
        if let cost = Double(costText), cost >= 0 {
            updated.unitCost = cost
        }
        updated.batchNumber = batchNumber.isEmpty ? nil : batchNumber
        updated.expiryDate = hasExpiry ? expiryDate : nil
        updated.notes = notes.isEmpty ? nil : notes
        onSave(updated)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ShoppingListDetailView(listId: UUID(), store: ShoppingListStore.shared)
            .environmentObject(AuthManager.shared)
    }
}
