import Foundation
import Testing
@testable import FarmaciaKit

/// The product-photo flow shared by Nuevo Producto and the product detail:
/// camera or library → crop → preview. Retomar goes back to where the photo came
/// from; cancelling any step closes the flow. (Generic over the image type so the
/// package stays UIKit-free; tests use a String as the "image".)
struct PhotoFlowTests {
    @Test("given a photo picked from the library, should go to the crop")
    func pickedGoesToCrop() {
        var flow = PhotoFlow<String>()
        flow.start(.library)
        flow.picked("photo")
        #expect(flow.step == .crop("photo"))
    }

    @Test("given a cropped photo, should go to the preview")
    func croppedGoesToPreview() {
        var flow = PhotoFlow<String>()
        flow.start(.camera)
        flow.picked("photo")
        flow.cropped()
        #expect(flow.step == .preview)
    }

    @Test("given a photo taken with the camera, retake should reopen the camera")
    func retakeReopensCamera() {
        var flow = PhotoFlow<String>()
        flow.start(.camera)
        flow.picked("photo")
        flow.cropped()
        flow.retake()
        #expect(flow.step == .pick(.camera))
    }

    @Test("given a photo from the library, retake should reopen the library")
    func retakeReopensLibrary() {
        var flow = PhotoFlow<String>()
        flow.start(.library)
        flow.picked("photo")
        flow.cropped()
        flow.retake()
        #expect(flow.step == .pick(.library))
    }

    @Test("given cancel at any step, should close the flow")
    func cancelCloses() {
        var flow = PhotoFlow<String>()
        flow.start(.library)
        flow.picked("photo")
        flow.cancel()
        #expect(flow.step == nil)
    }
}
