import SwiftUI
import FarmaciaKit

// MARK: - Tone Badge
//
// A short tag on a row or card ("Agotado", "32%", a lot number): bold caption
// text on a light tint of its color. Text style, not a fixed size, so it grows
// with Dynamic Type.

struct ToneBadge: View {
    let text: String
    let color: Color
    var systemImage: String?

    init(_ text: String, tone: Tone, systemImage: String? = nil) {
        self.init(text, color: tone.color, systemImage: systemImage)
    }

    /// For identity colors that aren't a status (e.g. a role or expense type).
    init(_ text: String, color: Color, systemImage: String? = nil) {
        self.text = text
        self.color = color
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption2)
        .fontWeight(.bold)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, 1)
        .background(color.opacity(0.15), in: .rect(cornerRadius: DS.Radius.s))
        .foregroundStyle(color)
    }
}

extension View {
    /// The product screens' card: padded, on the grouped gray, large radius.
    func card() -> some View {
        padding()
            .background(Color(.systemGray6), in: .rect(cornerRadius: DS.Radius.xl))
    }
}
