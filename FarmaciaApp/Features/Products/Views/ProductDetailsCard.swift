import SwiftUI
import FarmaciaKit

// MARK: - Product Details Card

struct ProductDetailsCard: View {
    let product: Product

    var body: some View {
        detailsCard
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            Text("Detalles")
                .font(.headline)

            // The Square description only when it says something the name doesn't.
            if let description = product.squareDescription, !description.isEmpty,
               description != product.displayName {
                detailRow(title: "Descripción", value: description)
            }

            if let category = product.category {
                detailRow(title: "Categoría", value: category.name)
            }

            if let createdAt = product.createdAt {
                detailRow(title: "Creado", value: DisplayDate.day(createdAt))
            }

            squareSyncLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func detailRow(title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    /// "Square POS sincronizado hace 2 días" — words + glyph, not a dot alone.
    private var squareSyncLine: some View {
        let synced = product.hasSquareSync == true
        let tone: Tone = synced ? .positive : .caution
        let detail = synced
            ? product.squareDataSyncedAt.map { "sincronizado \(DisplayDate.relative($0))" } ?? "sincronizado"
            : "solo local, no visible en Square"
        return HStack(spacing: DS.Spacing.xs) {
            Image(systemName: synced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tone.color)
            Text("Square POS")
                .fontWeight(.medium)
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
