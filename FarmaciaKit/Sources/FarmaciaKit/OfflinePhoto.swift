import Foundation

// MARK: - Offline Photo
//
// A product created offline keeps its photo on the device (the upload needs
// the product's server id, which doesn't exist yet). When the queued create
// syncs, its response names the product; the photo is uploaded for it and the
// stored file deleted. The app's OfflinePhotoStore holds the files; these are
// the pure rules.

public enum OfflinePhoto {
    /// The queued request is a product create (its replay can carry a photo).
    public static func isProductCreate(method: String, path: String) -> Bool {
        method == "POST" && path == "/products"
    }

    /// The create's idempotency key, which names the stored photo until the
    /// product's server id is known.
    public static func clientRequestId(fromBody body: Data?) -> String? {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return nil }
        return object["clientRequestId"] as? String
    }
}

/// What the offline queue reads from a replayed write's response: for a product
/// create, the new product's id. Decoding never fails — a response it doesn't
/// recognize just has no id — so it can't turn a successful replay into a
/// failed one.
public struct ReplayedWrite: Decodable, Sendable {
    public let productId: String?

    private enum Keys: String, CodingKey { case data, product, id }

    public init(from decoder: Decoder) throws {
        let root = try? decoder.container(keyedBy: Keys.self)
        let data = try? root?.nestedContainer(keyedBy: Keys.self, forKey: .data)
        let product = try? data?.nestedContainer(keyedBy: Keys.self, forKey: .product)
        productId = try? product?.decodeIfPresent(String.self, forKey: .id)
    }
}
