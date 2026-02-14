import SwiftUI

// MARK: - Receive Flow View
// Per-item receive with quantity confirmation, batch/expiry entry per item,
// partial receive support (receive 8 of 10), and the actual POST /inventory/receive calls.
//
// Flow: Review items → Toggle/adjust each → Confirm → Submitting → Complete

struct ReceiveFlowView: View {
    let listId: UUID
    @ObservedObject var store: ShoppingListStore
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var step: ReceiveStep = .review
    @State private var itemStates: [UUID: ReceiveItemState] = [:]
    @State private var submittedCount = 0
    @State private var failedCount = 0
    @State private var failedItems: [FailedReceiveItem] = []
    @State private var showError = false
    @State private var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    enum ReceiveStep {
        case review, submitting, complete
    }
    
    private var list: ShoppingList? {
        store.list(for: listId)
    }
    
    // Only unreceived items
    private var pendingItems: [ShoppingListItem] {
        list?.items.filter { !$0.isReceived } ?? []
    }
    
    private var selectedItems: [ShoppingListItem] {
        pendingItems.filter { itemStates[$0.id]?.isSelected ?? true }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .review:
                    reviewStep
                case .submitting:
                    submittingStep
                case .complete:
                    completeStep
                }
            }
            .navigationTitle(step == .review ? "Receive Items" : step == .submitting ? "Receiving..." : "Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .review {
                        Button("Cancelar") { dismiss() }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Ocurrió un error")
            }
            .onAppear {
                initializeStates()
            }
        }
    }
    
    // MARK: - Review Step
    
    private var reviewStep: some View {
        VStack(spacing: 0) {
            // Info header
            if let list = list {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.blue)
                        Text(list.supplierName ?? "Proveedor")
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(selectedItems.count) of \(pendingItems.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    // Select all / none
                    HStack {
                        Button("Select All") {
                            for item in pendingItems {
                                itemStates[item.id]?.isSelected = true
                            }
                        }
                        .font(.caption)
                        
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        Button("Select None") {
                            for item in pendingItems {
                                itemStates[item.id]?.isSelected = false
                            }
                        }
                        .font(.caption)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemGray6))
            }
            
            // Item list
            List {
                ForEach(pendingItems) { item in
                    ReceiveItemRow(
                        item: item,
                        state: bindingForState(item.id)
                    )
                }
            }
            .listStyle(.plain)
            
            // Receive button
            VStack(spacing: 8) {
                Divider()
                
                if !selectedItems.isEmpty {
                    let total = selectedItems.reduce(0.0) { sum, item in
                        let state = itemStates[item.id]
                        let qty = state?.receivedQuantity ?? item.plannedQuantity
                        return sum + Double(qty) * item.unitCost
                    }
                    
                    HStack {
                        Text("Total")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "$%.2f", total))
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }
                
                Button {
                    Task { await submitReceive() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Receive \(selectedItems.count) Items")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedItems.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(selectedItems.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Submitting Step
    
    private var submittingStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Receiving inventory...")
                .font(.headline)
            
            Text("Processing \(submittedCount + failedCount) of \(selectedItems.count) items")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ProgressView(
                value: Double(submittedCount + failedCount),
                total: Double(max(1, selectedItems.count))
            )
            .progressViewStyle(.linear)
            .padding(.horizontal, 60)
            
            Spacer()
        }
    }
    
    // MARK: - Complete Step
    
    private var completeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: failedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(failedCount == 0 ? .green : .orange)
            
            Text(failedCount == 0 ? "Items Received!" : "Partially Received")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 8) {
                Text("\(submittedCount) items received successfully")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if failedCount > 0 {
                    Text("\(failedCount) items failed")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                if let list = list {
                    if list.status == .completed {
                        Text("Shopping list completed!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    } else if list.status == .partiallyReceived {
                        Text("\(list.pendingCount) items still pending")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if !failedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Failed Items:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(failedItems, id: \.productName) { item in
                        Text("\u{2022} \(item.productName): \(item.error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Listo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding()
        }
    }
    
    // MARK: - State Management
    
    private func initializeStates() {
        for item in pendingItems {
            if itemStates[item.id] == nil {
                itemStates[item.id] = ReceiveItemState(
                    isSelected: true,
                    receivedQuantity: item.plannedQuantity,
                    batchNumber: item.batchNumber ?? "",
                    hasExpiry: item.expiryDate != nil,
                    expiryDate: item.expiryDate ?? Date().addingTimeInterval(365 * 24 * 60 * 60)
                )
            }
        }
    }
    
    private func bindingForState(_ itemId: UUID) -> Binding<ReceiveItemState> {
        Binding(
            get: {
                itemStates[itemId] ?? ReceiveItemState(
                    isSelected: true,
                    receivedQuantity: 0,
                    batchNumber: "",
                    hasExpiry: false,
                    expiryDate: Date()
                )
            },
            set: { itemStates[itemId] = $0 }
        )
    }
    
    // MARK: - Submit
    
    private func submitReceive() async {
        guard let list = list else { return }
        guard let supplierId = list.supplierId else {
            errorMessage = "No supplier assigned to this list"
            showError = true
            return
        }
        guard let locationId = authManager.currentLocation?.id else {
            errorMessage = "No location selected"
            showError = true
            return
        }
        
        let itemsToReceive = selectedItems
        guard !itemsToReceive.isEmpty else { return }
        
        withAnimation { step = .submitting }
        submittedCount = 0
        failedCount = 0
        failedItems = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for item in itemsToReceive {
            let state = itemStates[item.id]
            let qty = state?.receivedQuantity ?? item.plannedQuantity
            let batchNum: String? = {
                guard let state = state else { return nil }
                return state.batchNumber.isEmpty ? nil : state.batchNumber
            }()
            let expiryDateStr: String? = {
                guard let state = state, state.hasExpiry else { return nil }
                return dateFormatter.string(from: state.expiryDate)
            }()
            
            do {
                let request = ReceiveInventoryRequest(
                    locationId: locationId,
                    productId: item.productId,
                    quantity: qty,
                    unitCost: item.unitCost,
                    supplierId: supplierId,
                    invoiceNumber: list.invoiceNumber?.isEmpty == true ? nil : list.invoiceNumber,
                    purchaseOrderId: nil,
                    batchNumber: batchNum,
                    expiryDate: expiryDateStr,
                    manufacturingDate: nil,
                    receivedBy: authManager.currentEmployee?.id,
                    notes: list.notes?.isEmpty == true ? nil : list.notes.map { "Shopping List: \($0)" },
                    syncToSquare: true,
                    sellingPrice: nil,
                    syncPriceToSquare: nil
                )
                
                let _: ReceivingCreateResponse = try await apiClient.request(
                    endpoint: .receiveInventory,
                    body: request
                )
                
                // Mark item as received in the store
                store.markItemReceived(listId: listId, itemId: item.id, receivedQuantity: qty)
                submittedCount += 1
            } catch {
                failedCount += 1
                failedItems.append(FailedReceiveItem(
                    productName: item.productName,
                    error: error.localizedDescription
                ))
            }
        }
        
        withAnimation { step = .complete }
    }
}

// MARK: - Receive Item State

struct ReceiveItemState {
    var isSelected: Bool
    var receivedQuantity: Int
    var batchNumber: String
    var hasExpiry: Bool
    var expiryDate: Date
}

// MARK: - Failed Receive Item

struct FailedReceiveItem {
    let productName: String
    let error: String
}

// MARK: - Receive Item Row

struct ReceiveItemRow: View {
    let item: ShoppingListItem
    @Binding var state: ReceiveItemState
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main row
            HStack(spacing: 10) {
                // Selection toggle
                Button {
                    state.isSelected.toggle()
                } label: {
                    Image(systemName: state.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(state.isSelected ? .blue : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                
                // Product info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.productName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    if let sku = item.sku {
                        Text(sku)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Quantity controls
                if state.isSelected {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 6) {
                            Button {
                                if state.receivedQuantity > 1 {
                                    state.receivedQuantity -= 1
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(state.receivedQuantity <= 1 ? .gray : .red)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.receivedQuantity <= 1)
                            
                            Text("\(state.receivedQuantity)")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 30, alignment: .center)
                            
                            Button {
                                state.receivedQuantity += 1
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Show if different from planned
                        if state.receivedQuantity != item.plannedQuantity {
                            Text("of \(item.plannedQuantity) planned")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Text(String(format: "$%.2f", Double(state.receivedQuantity) * item.unitCost))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Expand for batch/expiry
            if state.isSelected && isExpanded {
                VStack(spacing: 8) {
                    // Batch number
                    HStack {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .frame(width: 16)
                        TextField("Lot / Batch #", text: $state.batchNumber)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                    
                    // Expiry date toggle
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .frame(width: 16)
                        Toggle("Expiry Date", isOn: $state.hasExpiry)
                            .font(.caption)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                    }
                    
                    if state.hasExpiry {
                        DatePicker(
                            "Expires",
                            selection: $state.expiryDate,
                            displayedComponents: .date
                        )
                        .font(.caption)
                        .datePickerStyle(.compact)
                    }
                }
                .padding(.leading, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state.isSelected {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }
        }
        .opacity(state.isSelected ? 1.0 : 0.5)
    }
}

// MARK: - Preview

#Preview {
    ReceiveFlowView(listId: UUID(), store: ShoppingListStore.shared)
        .environmentObject(AuthManager.shared)
}
