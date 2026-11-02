import Foundation

// MARK: - Photo Flow
//
// The product-photo flow shared by Nuevo Producto and the product detail:
// camera or library → crop → preview. One value drives the screen's single
// full-screen cover (`step`), so moving between steps swaps the cover's
// content instead of presenting one screen over another. Generic over the
// image type so the package stays UIKit-free.

public enum PhotoSource: Sendable, Equatable {
    case camera
    case library
}

public enum PhotoStep<Image> {
    case pick(PhotoSource)
    case crop(Image)
    case preview
}

extension PhotoStep: Equatable where Image: Equatable {}

/// So a screen's `fullScreenCover(item:)` can bind to `flow.step` directly.
extension PhotoStep: Identifiable {
    public var id: String {
        switch self {
        case .pick(.camera): "pick-camera"
        case .pick(.library): "pick-library"
        case .crop: "crop"
        case .preview: "preview"
        }
    }
}

public struct PhotoFlow<Image> {
    /// The step on screen; nil when the flow is closed (the cover's binding
    /// sets it to nil when the system dismisses it).
    public var step: PhotoStep<Image>?
    /// Where the current photo came from: Retomar goes back there.
    public private(set) var source: PhotoSource = .library

    public init() {}

    public mutating func start(_ source: PhotoSource) {
        self.source = source
        step = .pick(source)
    }

    public mutating func picked(_ image: Image) {
        step = .crop(image)
    }

    public mutating func cropped() {
        step = .preview
    }

    public mutating func retake() {
        step = .pick(source)
    }

    /// Cancelled at any step, or finished (Listo): closes the flow.
    public mutating func cancel() {
        step = nil
    }
}
