import SwiftUI
import FarmaciaKit

// MARK: - Store Strip
//
// A thin strip in the store's color under the nav bar of every stock-changing
// sheet, so nobody receives or counts into the wrong store. Hidden for
// employees with a single store (`StoreTint.showsStrip`).

extension View {
    /// Apply to the sheet's content inside its NavigationStack (the Form), so
    /// the strip sits under the nav bar.
    func storeStrip() -> some View {
        safeAreaInset(edge: .top, spacing: 0) { StoreStrip() }
    }
}

struct StoreStrip: View {
    @EnvironmentObject private var authManager: AuthManager

    /// Mid-dark tones, shown as the icon color and a light tint behind the name.
    /// No red or orange: the strip must never read as a warning.
    static let palette: [Color] = [
        Color(red: 0.12, green: 0.37, blue: 0.68),  // blue
        Color(red: 0.36, green: 0.25, blue: 0.71),  // indigo
        Color(red: 0.06, green: 0.48, blue: 0.43),  // teal
        Color(red: 0.18, green: 0.49, blue: 0.20),  // green
        Color(red: 0.56, green: 0.23, blue: 0.54),  // plum
        Color(red: 0.43, green: 0.33, blue: 0.21),  // brown
    ]

    static func color(forLocationId id: String) -> Color {
        palette[StoreTint.paletteIndex(forLocationId: id, paletteCount: palette.count)]
    }

    var body: some View {
        if let store = authManager.currentLocation,
           StoreTint.showsStrip(storeCount: authManager.availableLocations.count) {
            Self.bar(name: store.name, color: Self.color(forLocationId: store.id))
        }
    }

    static func bar(name: String, color: Color) -> some View {
        // Toned down: the color is on the icon, a tint and a bottom edge, not a solid fill.
        Label {
            Text(name).foregroundStyle(.primary)
        } icon: {
            Image(systemName: "building.2").foregroundStyle(color)
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xs)
        // No safe-area edges: by default the fill bled up behind the nav bar.
        .background(color.opacity(0.35), ignoresSafeAreaEdges: [])
        // A crisp edge in the full color, so the store reads at a glance.
        .overlay(alignment: .bottom) { color.frame(height: 2) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tienda: \(name)")
    }
}

#Preview {
    VStack(spacing: DS.Spacing.l) {
        StoreStrip.bar(name: "Sucursal Prueba", color: StoreStrip.color(forLocationId: "loc-prueba"))
        StoreStrip.bar(name: "farmacia dev ops", color: StoreStrip.color(forLocationId: "loc-devops"))
        ForEach(StoreStrip.palette.indices, id: \.self) { i in
            StoreStrip.bar(name: "Farmacia con un nombre muy largo, sucursal \(i)", color: StoreStrip.palette[i])
        }
    }
}
