import SwiftUI

// MARK: - Product Photo Preview
// Full-screen review step shown right after a product photo is picked (and,
// if a subject was detected, lifted): inspect it, retake it, or toggle the
// background-removal result off in favor of the plain photo.

struct ProductPhotoPreviewView: View {
    let liftedImage: UIImage?
    let originalImage: UIImage
    @Binding var backgroundRemoved: Bool
    /// Background removal still running: show the photo with a spinner.
    var isLifting = false
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
                if isLifting {
                    ProgressView("Quitando fondo…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: DS.Radius.l))
                }
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
            // Light status bar and bar items over the black bar.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if liftedImage != nil {
                    Toggle("Quitar Fondo", isOn: $backgroundRemoved)
                        .padding()
                        .background(Color.black)
                        .foregroundStyle(.white)
                }
            }
        }
        // Dark for this screen only. `.preferredColorScheme(.dark)` asks the
        // whole window to switch, so the screen underneath flashed dark while
        // the cover slid up.
        .environment(\.colorScheme, .dark)
    }
}
