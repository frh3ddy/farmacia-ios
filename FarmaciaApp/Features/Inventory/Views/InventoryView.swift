import SwiftUI

// MARK: - Inventory View

struct InventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedSegment: InventorySegment = .receive
    
    enum InventorySegment: String, CaseIterable {
        case receive = "Receive"
        case adjustments = "Adjustments"
        case history = "History"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Inventory", selection: $selectedSegment) {
                    ForEach(InventorySegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on segment
                switch selectedSegment {
                case .receive:
                    if authManager.canManageInventory {
                        ReceiveInventoryView()
                    } else {
                        noPermissionView
                    }
                case .adjustments:
                    if authManager.canManageInventory {
                        AdjustmentsListView()
                    } else {
                        noPermissionView
                    }
                case .history:
                    ReceivingHistoryView()
                }
            }
            .navigationTitle("Inventory")
        }
    }
    
    private var noPermissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Access Restricted")
                .font(.headline)
            
            Text("You don't have permission to access this feature.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Receive Inventory View

struct ReceiveInventoryView: View {
    @State private var showReceiveSheet = false
    
    var body: some View {
        VStack {
            // Quick action buttons
            VStack(spacing: 12) {
                Button {
                    showReceiveSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Receive New Inventory")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            
            Spacer()
            
            // Placeholder for recent receivings
            Text("Recent receivings will appear here")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .sheet(isPresented: $showReceiveSheet) {
            ReceiveInventoryFormView()
        }
    }
}

// MARK: - Receive Inventory Form View

struct ReceiveInventoryFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var productSearch = ""
    @State private var quantity = ""
    @State private var unitCost = ""
    @State private var invoiceNumber = ""
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Search product...", text: $productSearch)
                }
                
                Section("Quantity & Cost") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    TextField("Unit Cost", text: $unitCost)
                        .keyboardType(.decimalPad)
                }
                
                Section("Optional Details") {
                    TextField("Invoice Number", text: $invoiceNumber)
                    TextField("Notes", text: $notes)
                }
            }
            .navigationTitle("Receive Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save receiving
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

// MARK: - Adjustments List View

struct AdjustmentsListView: View {
    @State private var showAdjustmentSheet = false
    @State private var selectedAdjustmentType: AdjustmentType?
    
    var body: some View {
        VStack {
            // Quick adjustment buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([AdjustmentType.damage, .theft, .expired, .found, .returnType, .countCorrection], id: \.self) { type in
                        Button {
                            selectedAdjustmentType = type
                            showAdjustmentSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 70)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            
            Divider()
            
            // Placeholder for recent adjustments
            Text("Recent adjustments will appear here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showAdjustmentSheet) {
            if let type = selectedAdjustmentType {
                AdjustmentFormView(adjustmentType: type)
            }
        }
    }
}

// MARK: - Adjustment Form View

struct AdjustmentFormView: View {
    let adjustmentType: AdjustmentType
    @Environment(\.dismiss) var dismiss
    @State private var productSearch = ""
    @State private var quantity = ""
    @State private var reason = ""
    @State private var notes = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Search product...", text: $productSearch)
                }
                
                Section("Quantity") {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    
                    if adjustmentType.isVariable {
                        Text("Enter positive to add, negative to remove")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Details") {
                    TextField("Reason", text: $reason)
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle(adjustmentType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save adjustment
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
}

// MARK: - Receiving History View

struct ReceivingHistoryView: View {
    var body: some View {
        VStack {
            Text("Receiving history will appear here")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    InventoryView()
        .environmentObject(AuthManager.shared)
}
