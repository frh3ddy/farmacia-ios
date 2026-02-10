import SwiftUI

// MARK: - Batch Detail View
// Tapped from a FIFO batch row in ProductDetailView
// Shows full batch history: receiving metadata, consumption trail, remaining quantity

struct BatchDetailView: View {
    let batchId: String
    let productName: String
    
    @StateObject private var viewModel = BatchDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading batch history...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail = viewModel.batchDetail {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Batch overview card
                            overviewCard(detail)
                            
                            // Receiving metadata
                            if let receiving = detail.receiving {
                                receivingCard(receiving)
                            }
                            
                            // Adjustment metadata (if created by adjustment)
                            if let adjustment = detail.adjustment {
                                adjustmentCard(adjustment)
                            }
                            
                            // Quantity timeline
                            quantityCard(detail)
                            
                            // Consumption history
                            consumptionCard(detail)
                        }
                        .padding()
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("Failed to load batch")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Batch Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.loadBatchDetail(batchId: batchId)
        }
    }
    
    // MARK: - Overview Card
    
    private func overviewCard(_ detail: BatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundColor(.teal)
                Text("Batch Overview")
                    .font(.headline)
                Spacer()
                Text(detail.sourceLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            Divider()
            
            // Product
            HStack {
                Text(productName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let sku = detail.productSku {
                    Text(sku)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Key metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 12) {
                metricBox(value: "\(detail.quantity)", label: "Remaining", color: detail.quantity > 0 ? .green : .red)
                metricBox(value: detail.formattedUnitCost, label: "Unit Cost", color: .blue)
                metricBox(value: "\(detail.ageDays)d", label: "Age", color: detail.ageDays > 90 ? .red : detail.ageDays > 30 ? .orange : .green)
            }
            
            // Value and location
            HStack {
                Label(detail.locationName, systemImage: "building.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Value: \(detail.formattedCurrentValue)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Receiving Card
    
    private func receivingCard(_ receiving: BatchReceivingDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.green)
                Text("Receiving Details")
                    .font(.headline)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                if let supplier = receiving.supplierName {
                    infoRow(icon: "building.2", label: "Supplier", value: supplier, color: .blue)
                }
                if let lot = receiving.batchNumber, !lot.isEmpty {
                    infoRow(icon: "number", label: "Lot / Batch #", value: lot, color: .purple)
                }
                if let expiry = receiving.expiryDate {
                    let isExpired = expiry < Date()
                    infoRow(
                        icon: isExpired ? "exclamationmark.triangle.fill" : "calendar",
                        label: "Expiry Date",
                        value: expiry.formatted(date: .abbreviated, time: .omitted),
                        color: isExpired ? .red : .orange
                    )
                }
                if let mfg = receiving.manufacturingDate {
                    infoRow(icon: "hammer", label: "Manufacturing Date", value: mfg.formatted(date: .abbreviated, time: .omitted), color: .secondary)
                }
                if let invoice = receiving.invoiceNumber, !invoice.isEmpty {
                    infoRow(icon: "doc.text", label: "Invoice", value: invoice, color: .gray)
                }
                infoRow(icon: "clock", label: "Received", value: receiving.receivedAt.formatted(date: .abbreviated, time: .shortened), color: .secondary)
                if let notes = receiving.notes, !notes.isEmpty {
                    infoRow(icon: "note.text", label: "Notes", value: notes, color: .secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Adjustment Card
    
    private func adjustmentCard(_ adjustment: BatchAdjustmentDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
                Text("Created by Adjustment")
                    .font(.headline)
            }
            
            Divider()
            
            VStack(spacing: 8) {
                infoRow(icon: "tag", label: "Type", value: adjustment.type, color: .orange)
                if let reason = adjustment.reason {
                    infoRow(icon: "text.quote", label: "Reason", value: reason, color: .secondary)
                }
                infoRow(icon: "clock", label: "Adjusted", value: adjustment.adjustedAt.formatted(date: .abbreviated, time: .shortened), color: .secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Quantity Card
    
    private func quantityCard(_ detail: BatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.indigo)
                Text("Quantity Tracking")
                    .font(.headline)
            }
            
            Divider()
            
            // Progress bar showing remaining vs consumed
            VStack(spacing: 8) {
                HStack {
                    Text("Original: \(detail.originalQuantity) units")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(detail.remainingPercent)% remaining")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(detail.quantity > 0 ? .green : .red)
                }
                
                GeometryReader { geometry in
                    let remaining = detail.originalQuantity > 0
                        ? CGFloat(detail.quantity) / CGFloat(detail.originalQuantity)
                        : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(remaining > 0.5 ? Color.green : remaining > 0.2 ? Color.orange : Color.red)
                            .frame(width: geometry.size.width * remaining, height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Label("\(detail.quantity) remaining", systemImage: "cube.box")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                    Label("\(detail.totalConsumed) consumed", systemImage: "arrow.right.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Consumption Card
    
    private func consumptionCard(_ detail: BatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.blue)
                Text("Consumption History")
                    .font(.headline)
                Spacer()
                Text("\(detail.consumptionCount) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            if detail.consumptions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("No consumption records yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("This batch hasn't been consumed by any sales or adjustments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(detail.consumptions) { consumption in
                    HStack(spacing: 10) {
                        // Type icon
                        Image(systemName: consumption.typeIcon)
                            .font(.caption)
                            .foregroundColor(consumption.typeColor)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(consumption.typeLabel)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if let sale = consumption.sale {
                                    Text("(#\(sale.squareId.suffix(6)))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Text(consumption.consumedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("-\(consumption.quantity) units")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Text(consumption.formattedTotalCost)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if consumption.id != detail.consumptions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private func metricBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
    
    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

// MARK: - Batch Detail ViewModel

@MainActor
class BatchDetailViewModel: ObservableObject {
    @Published var batchDetail: BatchDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiClient = APIClient.shared
    
    func loadBatchDetail(batchId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response: BatchDetailResponse = try await apiClient.request(
                endpoint: .batchDetail(batchId: batchId)
            )
            batchDetail = response.data
        } catch {
            print("Failed to load batch detail: \(error)")
            errorMessage = error.localizedDescription
            batchDetail = nil
        }
    }
}

// MARK: - Preview

#Preview {
    BatchDetailView(batchId: "test-batch-1", productName: "Paracetamol 500mg")
}
