import SwiftUI

// MARK: - Product Photo Preview
// Full-screen review step shown right after a product photo is picked (and,
// if a subject was detected, lifted): inspect it, retake it, or toggle the
// background-removal result off in favor of the plain photo.

struct ProductPhotoPreviewView: View {
    let liftedImage: UIImage?
    let originalImage: UIImage
    @Binding var backgroundRemoved: Bool
    let onRetake: () -> Void
    let onDone: () -> Void

    private var displayedImage: UIImage {
        (backgroundRemoved ? liftedImage : nil) ?? originalImage
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo") { onDone() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Retomar Foto", role: .destructive) { onRetake() }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if liftedImage != nil {
                    Toggle("Quitar Fondo", isOn: $backgroundRemoved)
                        .padding()
                        .background(Color.black)
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
