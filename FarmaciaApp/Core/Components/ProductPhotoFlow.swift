import SwiftUI
import FarmaciaKit
import SwiftyCrop

// MARK: - Product Photo Flow
//
// The full-screen side of the product-photo flow (FarmaciaKit `PhotoFlow`):
// camera or library → square crop → the screen's own preview. One cover bound
// to `flow.step`; each step swaps its content, so nothing is presented over
// anything else. Used by Nuevo Producto and the product detail.

extension View {
    /// - Parameters:
    ///   - onCropped: the square photo, as the flow moves on to the preview
    ///     (start background removal here).
    ///   - preview: the screen's preview step (Retomar → `flow.retake()`,
    ///     Listo → `flow.cancel()`).
    func productPhotoFlow<Preview: View>(
        _ flow: Binding<PhotoFlow<UIImage>>,
        onCropped: @escaping (UIImage) -> Void,
        @ViewBuilder preview: @escaping () -> Preview
    ) -> some View {
        fullScreenCover(item: flow.step) { step in
            switch step {
            case .pick(.camera):
                CameraPicker(
                    onPicked: { flow.wrappedValue.picked($0) },
                    onCancel: { flow.wrappedValue.cancel() }
                )
                .ignoresSafeArea()
            case .pick(.library):
                LibraryPicker(
                    onPicked: { flow.wrappedValue.picked($0) },
                    onCancel: { flow.wrappedValue.cancel() }
                )
            case .crop(let image):
                SwiftyCropView(
                    imageToCrop: image,
                    maskShape: .square,
                    // ponytail: SwiftyCrop scales magnification gesture magnitude
                    // by 0.1 * zoomSensitivity internally, so the default (1.0) only
                    // applies 10% of the pinch as zoom. 8 gets close to a native,
                    // 1:1-feeling pinch; retune if it still feels off.
                    // dismissesOnCompletion: false — the flow owns the cover.
                    // SwiftyCrop otherwise calls dismiss() right after
                    // onComplete, which closed the cover we had just moved on
                    // to the preview (no preview, nothing uploaded).
                    configuration: SwiftyCropConfiguration(zoomSensitivity: 8, dismissesOnCompletion: false),
                    onCancel: { flow.wrappedValue.cancel() }
                ) { cropped in
                    guard let cropped else {
                        flow.wrappedValue.cancel()
                        return
                    }
                    onCropped(cropped)
                    flow.wrappedValue.cropped()
                }
            case .preview:
                preview()
            }
        }
    }
}
