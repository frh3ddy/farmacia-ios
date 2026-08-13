import SwiftUI

// MARK: - All Signals View (full list)

struct AllSignalsView: View {
    let signals: [ActionableSignal]
    @State private var selectedType: SignalTypeFilter = .all
    
    enum SignalTypeFilter: String, CaseIterable {
        case all = "Todos"
        case atRisk = "En Riesgo"
        case slowMoving = "Lento Movimiento"
        case overstocked = "Sobrestock"
    }
    
    private var filteredSignals: [ActionableSignal] {
        switch selectedType {
        case .all: return signals
        case .atRisk: return signals.filter { $0.type == .atRisk }
        case .slowMoving: return signals.filter { $0.type == .slowMovingExpensive }
        case .overstocked: return signals.filter { $0.type == .overstockedCategory }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Tipo", selection: $selectedType) {
                ForEach(SignalTypeFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List {
                if filteredSignals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                        Text("No hay señales en esta categoría")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredSignals) { signal in
                        SignalDetailRow(signal: signal)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Señales de Acción")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SignalDetailRow: View {
    let signal: ActionableSignal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: signal.type.icon)
                    .font(.subheadline)
                    .foregroundStyle(signal.severity.color)
                    .frame(width: 32, height: 32)
                    .background(signal.severity.color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.entityName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(signal.type.displayName)
                            .font(.caption)
                            .foregroundStyle(signal.type.color)
                        
                        Text("\u{2022}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(signal.severity.displayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(signal.severity.color)
                    }
                }
                
                Spacer()
                
                if let cash = signal.formattedCashAtRisk {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(cash)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                        Text("en riesgo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Message
            Text(signal.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Recommended actions
            if !signal.recommendedActions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Acciones Recomendadas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    ForEach(signal.recommendedActions, id: \.self) { action in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text(action)
                                .font(.caption)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

