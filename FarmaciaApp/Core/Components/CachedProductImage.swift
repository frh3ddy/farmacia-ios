import SwiftUI
import UIKit
import ImageIO

// MARK: - Product Image Cache
//
// In-memory cache of DOWNSAMPLED images (target pixel size, not full
// resolution). Combined with a shared URLCache for the raw network data,
// this gives the same practical benefit as Nuke without a dependency:
//   1. URLCache  — raw bytes from the network are reused across views
//   2. NSCache   — decoded thumbnails at display size are reused instantly
//   3. ImageIO   — thumbnail decode happens at the target size, so a 12 MP
//                  photo never gets fully decoded into memory for a 50 pt row

final class ProductImageCache {
    static let shared = ProductImageCache()

    /// Key format: "url#WxH" (pixel size) -> downsampled UIImage
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // ~40 thumbnails is plenty for visible rows + scrollback
        cache.countLimit = 100
        // iOS evicts automatically on memory pressure
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String, pixelCost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: pixelCost)
    }

    /// Invalidate cached copies of a URL (all sizes) — used after a new
    /// image is uploaded so the fresh one is fetched.
    func invalidate(url: String) {
        // NSCache has no key enumeration; removing exact variants would miss
        // sizes. Simplest correct approach: drop the whole cache (cheap —
        // it only holds thumbnails and refills on demand).
        cache.removeAllObjects()
    }
}

// MARK: - Product Image Loader

@MainActor
final class ProductImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false

    private var task: Task<Void, Never>?

    /// Loads `url` downsampled to `targetSize` (in points, converted to
    /// pixels using the main screen scale).
    func load(url: URL?, targetSize: CGSize) {
        task?.cancel()

        guard let url else {
            image = nil
            return
        }

        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale,
                               height: targetSize.height * scale)
        let key = "\(url.absoluteString)#\(Int(pixelSize.width))x\(Int(pixelSize.height))"

        if let cached = ProductImageCache.shared.image(for: key) {
            image = cached
            return
        }

        isLoading = true
        task = Task.detached(priority: .userInitiated) { [weak self] in
            defer { Task { @MainActor in self?.isLoading = false } }

            do {
                // URLSession uses URLCache.shared (configured at app launch)
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    return
                }

                guard let downsampled = Self.downsample(data: data, to: pixelSize),
                      !Task.isCancelled else { return }

                let pixelCost = Int(pixelSize.width * pixelSize.height * 4)
                ProductImageCache.shared.insert(downsampled, for: key, pixelCost: pixelCost)

                await MainActor.run { self?.image = downsampled }
            } catch {
                // Silent fail — views show the placeholder
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: - ImageIO Downsampling

    /// Decodes `data` directly at `max(pixelSize)` — never materializes the
    /// full-resolution image. This is the single biggest memory win for
    /// camera-roll-size product photos shown in 44–100 pt slots.
    nonisolated static func downsample(data: Data, to pixelSize: CGSize) -> UIImage? {
        let options: CFDictionary = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return nil
        }

        let maxDimension = max(pixelSize.width, pixelSize.height)
        let thumbnailOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Cached Product Image (SwiftUI view)

/// Drop-in replacement for `AsyncImage` in product UIs.
///
///     CachedProductImage(url: product.squareImageUrl, targetSize: CGSize(width: 50, height: 50))
///
/// Always pair with `.frame(width:height:)` matching `targetSize`.
struct CachedProductImage<Placeholder: View>: View {
    let urlString: String?
    let targetSize: CGSize
    let placeholder: () -> Placeholder

    @StateObject private var loader = ProductImageLoader()

    init(url urlString: String?,
         targetSize: CGSize,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.urlString = urlString
        self.targetSize = targetSize
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load(url: URL(string: urlString ?? ""), targetSize: targetSize)
        }
        .onChange(of: urlString) { _, newValue in
            loader.load(url: URL(string: newValue ?? ""), targetSize: targetSize)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}
