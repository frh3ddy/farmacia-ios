import SwiftUI

// MARK: - Optional Header

/// Section headers of optional sections: "Identificación  Opcional".
struct OptionalHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Text(title)
            Text("Opcional")
                .textCase(nil)
                .foregroundStyle(.tertiary)
        }
    }
}
