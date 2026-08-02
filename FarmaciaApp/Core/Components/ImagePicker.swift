import UIKit

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
            picker.allowsEditing = true

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
            // Prefer edited image (cropped), fall back to original
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            picker.dismiss(animated: true)
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
