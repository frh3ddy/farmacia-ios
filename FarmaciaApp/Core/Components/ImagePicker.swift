import UIKit
import SwiftUI
import PhotosUI

// MARK: - Camera / Library as screen content
//
// For screens that drive their photo flow from one `fullScreenCover(item:)`
// (a destination enum: camera → crop → preview). These are plain views, so the
// flow moves by swapping the cover's item — SwiftUI dismisses the current
// content and shows the new one — with no UIKit presentation of our own and
// nothing to race. `ImagePickerPresenter` below stays until its last caller
// (ProductDetailView) moves over.

/// The system camera. Fill the cover with it (`.ignoresSafeArea()`).
struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onPicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onPicked(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

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

// MARK: - Direct UIKit Image Picker Presentation
//
// SwiftUI's .sheet machinery has a presentation race when chained after a
// confirmationDialog: the dialog's binding flips to false when the dismiss
// animation STARTS, and any sheet presented while UIKit is still animating
// gets cancelled (camera opened and closed instantly on first attempt).
// Presenting the picker directly on the topmost view controller bypasses
// SwiftUI's presentation machinery entirely and is reliable every time.
// Camera is presented full-screen per Apple's HIG; the photo library uses
// a page sheet with grabber for familiar dismissal.

enum ImagePickerPresenter {
    static func present(
        sourceType: UIImagePickerController.SourceType,
        onImagePicked: @escaping (UIImage) -> Void
    ) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }

        // Defer one runloop so any in-flight dismiss animation (e.g. the
        // confirmation dialog that triggered this) finishes first.
        DispatchQueue.main.async {
            guard let top = topViewController() else { return }

            let picker = UIImagePickerController()
            picker.sourceType = sourceType
            // Cropping is handled by SwiftyCrop after the image is picked,
            // so the picker returns the untouched original.

            let delegate = Delegate(onImagePicked: onImagePicked)
            picker.delegate = delegate
            // Keep the delegate alive for the picker's lifetime
            objc_setAssociatedObject(picker, &delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            if sourceType == .camera {
                picker.modalPresentationStyle = .fullScreen
            }

            top.present(picker, animated: true)
        }
    }

    private static var delegateKey: UInt8 = 0

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        // Walk up any in-progress presentation chain (dialog, sheets, nav)
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private final class Delegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Hand the image over only after the picker is gone: callers
            // present the next screen (e.g. the crop cover) from it, and UIKit
            // refuses to present while the full-screen camera is still up.
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { [onImagePicked] in
                if let image { onImagePicked(image) }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Product Image Upload Response

struct ImageUploadResponse: Decodable {
    let success: Bool
    let imageUrl: String?
    let squareSynced: Bool?
    let squareImageId: String?
    let message: String?
}
