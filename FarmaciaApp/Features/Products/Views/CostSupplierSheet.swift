import SwiftUI
import FarmaciaKit

// MARK: - Cost Supplier Sheet
// The detail's "Costos y proveedores" sheet: current suppliers and each one's cost history.

struct CostSupplierSheet: View {
    let suppliers: [ProductSupplier]
    let costHistory: [SupplierCostHistoryGroup]
    let isLoading: Bool
    let onDone: () -> Void

    @State private var expandedSupplierHistory: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                costSupplierHistorySection
                    .padding()
            }
            .navigationTitle("Costos y proveedores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", action: onDone)
                }
            }
        }
    }

    private var costSupplierHistorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.l) {
            if isLoading && suppliers.isEmpty {
                // Skeleton in the shape of a supplier row.
                HStack(spacing: DS.Spacing.m) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Nombre del proveedor")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Notas")
                            .font(.caption)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text("$00.00")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("c/u")
                            .font(.caption2)
                    }
                }
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cargando datos de proveedor")
            } else if suppliers.isEmpty && costHistory.isEmpty {
                VStack(spacing: DS.Spacing.s) {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Sin datos de proveedor aún")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Los costos de proveedores aparecerán aquí cuando se reciban productos de proveedores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.m)
            } else {
                // Current Suppliers section (from SupplierProduct)
                if !suppliers.isEmpty {
                    Text("Proveedores Actuales")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(suppliers) { supplier in
                        HStack(spacing: DS.Spacing.m) {
                            // Supplier icon
                            ZStack {
                                Circle()
                                    .fill(supplier.isPreferred ? Color.blue.opacity(0.15) : Color(.systemGray5))
                                    .frame(width: 36, height: 36)
                                Image(systemName: supplier.isPreferred ? "star.fill" : "building.2")
                                    .font(.caption)
                                    .foregroundStyle(supplier.isPreferred ? Color.blue : Color.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                HStack(spacing: DS.Spacing.xs) {
                                    Text(supplier.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if supplier.isPreferred {
                                        Text("Preferido")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundStyle(.blue)
                                            .clipShape(.rect(cornerRadius: DS.Radius.s))
                                    }
                                }
                                if let notes = SupplierNote.display(supplier.notes) {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                                Text(supplier.formattedCost)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("c/u")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                }
                
                // Cost History section (from SupplierCostHistory)
                if !costHistory.isEmpty {
                    if !suppliers.isEmpty {
                        Divider()
                    }
                    
                    Text("Historial de Costos por Proveedor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(costHistory) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            // Supplier header with trend
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedSupplierHistory == group.supplierId {
                                        expandedSupplierHistory = nil
                                    } else {
                                        expandedSupplierHistory = group.supplierId
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(group.supplierName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    
                                    if let current = group.currentCost {
                                        Text(current.formattedCost)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    // Cost trend indicator
                                    if let trend = group.costTrend {
                                        HStack(spacing: DS.Spacing.xxs) {
                                            Image(systemName: trend.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                                .font(.caption2)
                                            Text(String(format: "%.1f%%", abs(trend.percent)))
                                                .font(.caption2)
                                        }
                                        .foregroundStyle((trend.change > 0 ? Tone.critical : Tone.positive).color)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(group.costHistory.count) registro\(group.costHistory.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    
                                    Image(systemName: expandedSupplierHistory == group.supplierId ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // Expanded cost timeline
                            if expandedSupplierHistory == group.supplierId {
                                ForEach(group.costHistory.prefix(10)) { entry in
                                    HStack(spacing: DS.Spacing.s) {
                                        // Timeline dot
                                        Circle()
                                            .fill(entry.isCurrent ? Color.blue : Color(.systemGray4))
                                            .frame(width: 6, height: 6)
                                        
                                        Text(DisplayDate.day(entry.effectiveAt))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 80, alignment: .leading)
                                        
                                        Text(entry.formattedCost)
                                            .font(.caption)
                                            .fontWeight(entry.isCurrent ? .semibold : .regular)
                                        
                                        Spacer()
                                        
                                        Text(entry.sourceLabel)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        if entry.isCurrent {
                                            Text("Actual")
                                                .font(.caption2)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundStyle(.blue)
                                                .clipShape(.rect(cornerRadius: 3))
                                        }
                                    }
                                    .padding(.leading, DS.Spacing.l)
                                }
                                
                                if group.costHistory.count > 10 {
                                    Text("+ \(group.costHistory.count - 10) registros más")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, DS.Spacing.l)
                                }
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                        
                        if group.supplierId != costHistory.last?.supplierId {
                            Divider()
                        }
                    }
                }
            }
        }
        .card()
    }
}
