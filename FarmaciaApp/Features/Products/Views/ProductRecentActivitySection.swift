import SwiftUI
import FarmaciaKit

// MARK: - Product Recent Activity Section

struct ProductRecentActivitySection<Activity: View>: View {
    let items: [ProductActivityItem]
    let isLoading: Bool
    /// Where "Ver toda la actividad" leads.
    @ViewBuilder let activity: () -> Activity

    var body: some View {
        recentActivitySection
    }

    /// Nothing happened yet → one 44pt row; otherwise the last 5 and "Ver toda la actividad".
    @ViewBuilder
    private var recentActivitySection: some View {
        let items = items
        switch ListPreview(count: items.count, limit: 5) {
        case .collapsed:
            EmptyRow(text: isLoading ? "Cargando movimientos…" : "Sin movimientos aún",
                     systemImage: "clock.arrow.circlepath")
        case .list(let shown, let hasMore):
            let visible = Array(items.prefix(shown))
            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                HStack {
                    Label("Actividad reciente", systemImage: "clock.arrow.circlepath")
                        .font(.headline)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                ForEach(visible) { item in
                    activityRow(item)
                    if item.id != visible.last?.id {
                        Divider()
                    }
                }

                if hasMore {
                    NavigationLink {
                        activity()
                    } label: {
                        HStack {
                            Text("Ver toda la actividad")
                            Spacer()
                            Text("\(items.count) en total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .frame(minHeight: DS.minTapSize)
                    }
                }
            }
            .card()
        }
    }
    
    @ViewBuilder
    private func activityRow(_ item: ProductActivityItem) -> some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: item.icon)
                .font(.subheadline)
                .foregroundStyle(item.iconColor)
                .frame(width: 28, height: 28)
                .background(item.iconColor.opacity(0.12))
                .clipShape(.rect(cornerRadius: 6))
            
            // Description
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Quantity change
            Text(item.quantityDisplay)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(item.quantityColor)
        }
        .padding(.vertical, DS.Spacing.xxs)
    }
}
