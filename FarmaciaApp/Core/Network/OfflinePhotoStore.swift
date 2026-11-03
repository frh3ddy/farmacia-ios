import Foundation

// MARK: - Offline Photo Store
//
// Photos of products created offline (FarmaciaKit `OfflinePhoto`), as JPEG
// files in Application Support — not Caches, which iOS may purge before the
// queue syncs. Named "request-<clientRequestId>.jpg" while the create is
// queued, renamed "product-<productId>.jpg" once it syncs; the offline queue
// uploads those and deletes each file after its upload succeeds.

enum OfflinePhotoStore {
    private static var directory: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let dir = base.appendingPathComponent("OfflinePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Ids become file names: only plain ones (UUIDs, cuids).
    private static func file(_ prefix: String, _ id: String) -> URL? {
        guard !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        return directory?.appendingPathComponent("\(prefix)-\(id).jpg")
    }

    /// Keeps the photo of a create that was queued offline. False if it couldn't be saved.
    @discardableResult
    static func save(_ jpeg: Data, forRequest requestId: String) -> Bool {
        guard let url = file("request", requestId) else { return false }
        return (try? jpeg.write(to: url, options: .atomic)) != nil
    }

    /// The queued create synced as `productId`: its photo now waits for upload.
    static func adopt(request requestId: String, productId: String) {
        guard let from = file("request", requestId), let to = file("product", productId),
              FileManager.default.fileExists(atPath: from.path) else { return }
        try? FileManager.default.removeItem(at: to)
        try? FileManager.default.moveItem(at: from, to: to)
    }

    /// The queued create was discarded: its photo goes too.
    static func removeRequestPhoto(_ requestId: String) {
        guard let url = file("request", requestId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Photos of synced products, waiting for (or retrying) their upload.
    static func pendingUploads() -> [(productId: String, url: URL)] {
        guard let dir = directory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.compactMap { name in
            guard name.hasPrefix("product-"), name.hasSuffix(".jpg") else { return nil }
            let id = String(name.dropFirst("product-".count).dropLast(".jpg".count))
            return (id, dir.appendingPathComponent(name))
        }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
