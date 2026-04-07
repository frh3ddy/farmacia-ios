import SwiftUI

// MARK: - Shopping Lists View
// Home screen for all shopping lists. Shows active lists (draft, ready, partially received)
// at the top, completed lists below. Create new, delete, duplicate, and navigate to detail.

struct ShoppingListsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: ShoppingListStore
    
    @State private var showCreateSheet = false
    @State private var showDeleteCompletedAlert = false
    @State private var selectedListId: UUID?
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if store.lists.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Listas de Compras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Listo") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !store.completedLists.isEmpty {
                            Menu {
                                Button(role: .destructive) {
                                    showDeleteCompletedAlert = true
                                } label: {
                                    Label("Clear Completed", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                        
                        Button {
                            showCreateSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateShoppingListSheet(store: store) { newListId in
                    navigationPath.append(newListId)
                }
            }
            .alert("Clear Completed Lists?", isPresented: $showDeleteCompletedAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    store.deleteCompleted()
                }
            } message: {
                Text("This will remove \(store.completedLists.count) completed shopping list(s). This cannot be undone.")
            }
            .navigationDestination(for: UUID.self) { listId in
                ShoppingListDetailView(listId: listId, store: store)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "list.clipboard")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.6))
            
            Text("Sin Listas de Compras")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Create a shopping list to plan your purchases.\nAdd items over time, then receive them when the stock arrives.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showCreateSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Shopping List")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - List Content
    
    private var listContent: some View {
        List {
            // Active lists
            let active = store.activeLists
            if !active.isEmpty {
                Section {
                    ForEach(active) { list in
                        NavigationLink(value: list.id) {
                            ShoppingListRow(list: list)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { active[$0].id }
                        for id in ids { store.delete(id) }
                    }
                } header: {
                    Text("Active (\(active.count))")
                }
            }
            
            // Completed lists
            let completed = store.completedLists
            if !completed.isEmpty {
                Section {
                    ForEach(completed) { list in
                        NavigationLink(value: list.id) {
                            ShoppingListRow(list: list)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { completed[$0].id }
                        for id in ids { store.delete(id) }
                    }
                } header: {
                    Text("Completed (\(completed.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Shopping List Row

struct ShoppingListRow: View {
    let list: ShoppingList
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: list.status.icon)
                .font(.title3)
                .foregroundColor(statusColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                // Name + badge
                HStack(spacing: 6) {
                    Text(list.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(list.status.label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                }
                
                // Details line
                HStack(spacing: 8) {
                    if let supplier = list.supplierName {
                        Label(supplier, systemImage: "building.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(itemSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(list.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Total
            Text(list.formattedPlannedTotal)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
    
    private var statusColor: Color {
        switch list.status {
        case .draft: return .gray
        case .ready: return .blue
        case .partiallyReceived: return .orange
        case .completed: return .green
        }
    }
    
    private var itemSummary: String {
        if list.status == .partiallyReceived {
            return "\(list.receivedCount)/\(list.itemCount) received"
        }
        return "\(list.itemCount) item\(list.itemCount == 1 ? "" : "s")"
    }
}

// MARK: - Create Shopping List Sheet (Phase C: "From Previous List" option)

struct CreateShoppingListSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: ShoppingListStore
    var onCreate: (UUID) -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var selectedSupplier: Supplier?
    @State private var notes = ""
    @State private var suppliers: [Supplier] = []
    @State private var isLoadingSuppliers = false
    @State private var showSupplierPicker = false
    @State private var showPreviousListPicker = false
    @State private var selectedPreviousList: ShoppingList?
    
    private let apiClient = APIClient.shared
    
    /// Previous lists available for duplication (any list with items)
    private var previousLists: [ShoppingList] {
        store.lists.filter { !$0.items.isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Weekly restock, Levic run", text: $name)
                } header: {
                    Text("Nombre de la Lista")
                } footer: {
                    Text("Give your list a name you'll recognize later.")
                }
                
                Section {
                    Button {
                        showSupplierPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                            
                            if let supplier = selectedSupplier {
                                Text(supplier.name)
                                    .foregroundColor(.primary)
                            } else {
                                Text("None — assign later")
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedSupplier != nil {
                                Button {
                                    selectedSupplier = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Supplier (Optional)")
                } footer: {
                    Text("You can assign a supplier now or later. Required before receiving items.")
                }
                
                // Phase C: From Previous List
                if !previousLists.isEmpty {
                    Section {
                        Button {
                            showPreviousListPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.secondary)
                                
                                if let prevList = selectedPreviousList {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(prevList.name)
                                            .foregroundColor(.primary)
                                        Text("\(prevList.itemCount) items \u{2022} \(prevList.formattedPlannedTotal)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Start from scratch")
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedPreviousList != nil {
                                    Button {
                                        selectedPreviousList = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("From Previous List (Optional)")
                    } footer: {
                        Text("Copy items from a previous list to get started quickly.")
                    }
                }
                
                Section {
                    TextField("Any notes about this order...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes (Optional)")
                }
            }
            .navigationTitle("Nueva Lista de Compras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Crear") {
                        createList()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showSupplierPicker) {
                SupplierPickerSheet(
                    suppliers: suppliers,
                    isLoading: isLoadingSuppliers,
                    selected: $selectedSupplier
                )
            }
            .sheet(isPresented: $showPreviousListPicker) {
                PreviousListPickerSheet(
                    lists: previousLists,
                    selected: $selectedPreviousList
                )
            }
            .task {
                await loadSuppliers()
            }
        }
    }
    
    private func createList() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if let previousList = selectedPreviousList {
            // Phase C: Duplicate from previous list with new name/supplier
            var newList = ShoppingList(
                name: trimmedName,
                supplierId: selectedSupplier?.id ?? previousList.supplierId,
                supplierName: selectedSupplier?.name ?? previousList.supplierName,
                locationId: authManager.currentLocation?.id,
                locationName: authManager.currentLocation?.name,
                notes: notes.isEmpty ? nil : notes
            )
            
            // Copy items but reset received state
            newList.items = previousList.items.map { item in
                ShoppingListItem(
                    productId: item.productId,
                    productName: item.productName,
                    sku: item.sku,
                    plannedQuantity: item.plannedQuantity,
                    unitCost: item.unitCost,
                    previousCost: item.previousCost
                )
            }
            
            store.save(newList)
            
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onCreate(newList.id)
            }
        } else {
            // Standard creation (no template)
            let list = store.createList(
                name: trimmedName,
                supplierId: selectedSupplier?.id,
                supplierName: selectedSupplier?.name,
                locationId: authManager.currentLocation?.id,
                locationName: authManager.currentLocation?.name,
                notes: notes.isEmpty ? nil : notes
            )
            
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onCreate(list.id)
            }
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

// MARK: - Previous List Picker Sheet (Phase C)

struct PreviousListPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let lists: [ShoppingList]
    @Binding var selected: ShoppingList?
    
    @State private var searchText = ""
    
    private var filteredLists: [ShoppingList] {
        if searchText.isEmpty { return lists }
        let query = searchText.lowercased()
        return lists.filter {
            $0.name.lowercased().contains(query) ||
            ($0.supplierName?.lowercased().contains(query) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if lists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No previous lists available")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(filteredLists) { list in
                            Button {
                                selected = list
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    // Status icon
                                    Image(systemName: list.status.icon)
                                        .font(.title3)
                                        .foregroundColor(statusColor(list.status))
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(list.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 6) {
                                            if let supplier = list.supplierName {
                                                Label(supplier, systemImage: "building.2")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Text("\(list.itemCount) items")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text(list.formattedPlannedTotal)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text(list.formattedDate)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selected?.id == list.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search lists")
                }
            }
            .navigationTitle("From Previous List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func statusColor(_ status: ShoppingListStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .ready: return .blue
        case .partiallyReceived: return .orange
        case .completed: return .green
        }
    }
}

// MARK: - Supplier Picker Sheet

struct SupplierPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let suppliers: [Supplier]
    let isLoading: Bool
    @Binding var selected: Supplier?
    
    @State private var searchText = ""
    
    var filteredSuppliers: [Supplier] {
        if searchText.isEmpty { return suppliers }
        let query = searchText.lowercased()
        return suppliers.filter { $0.name.lowercased().contains(query) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading suppliers...")
                } else if suppliers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No suppliers found")
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(filteredSuppliers) { supplier in
                            Button {
                                selected = supplier
                                dismiss()
                            } label: {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Text(String(supplier.name.prefix(1)).uppercased())
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text(supplier.name)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if selected?.id == supplier.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search suppliers")
                }
            }
            .navigationTitle("Select Supplier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ShoppingListsView(store: ShoppingListStore.shared)
        .environmentObject(AuthManager.shared)
}
