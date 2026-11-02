import UIKit
import SwiftUI

// MARK: - Camera as screen content
//
// The camera step of the product-photo flow (`.productPhotoFlow`, FarmaciaKit
// `PhotoFlow`): a plain view inside the flow's one full-screen cover, so the
// flow moves by swapping the cover's item — no UIKit presentation of our own
// and nothing to race. (Replaces `ImagePickerPresenter`, which presented
// UIImagePickerController on the top view controller to dodge a SwiftUI
// presentation race; the Menu + single-cover flow doesn't have that race.)

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
