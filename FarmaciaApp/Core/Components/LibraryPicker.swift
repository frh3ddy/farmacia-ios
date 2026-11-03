import SwiftUI
import PhotosUI

// MARK: - Library as screen content
//
// The library step of the product-photo flow (`.productPhotoFlow`).

/// The photo library, embedded (inline `PhotosPicker`, no permission prompt).
struct LibraryPicker: View {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var item: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            PhotosPicker("Elegir Foto", selection: $item, matching: .images)
                .photosPickerStyle(.inline)
                .photosPickerDisabledCapabilities(.selectionActions)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Elegir Foto")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar", action: onCancel)
                    }
                }
        }
        .task(id: item) {
            guard let item,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else { return }
            onPicked(image)
        }
    }
}
