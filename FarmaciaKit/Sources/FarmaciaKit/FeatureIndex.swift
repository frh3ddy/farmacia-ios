import Foundation

// MARK: - Feature Index
//
// The phone's cached image vectors for Buscar por foto (tasks/photo-search-epic.md),
// one per sin-código product with a photo. Plain [Float], never Vision types, so it
// saves as JSON and FarmaciaKit stays Foundation-only. Vectors from different Vision
// revisions can't be compared, and a changed photo URL means a new photo.

public struct FeatureIndex: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let imageUrl: String
        public let vector: [Float]
        public init(imageUrl: String, vector: [Float]) {
            self.imageUrl = imageUrl
            self.vector = vector
        }
    }

    public struct Ref: Equatable, Sendable {
        public let id: String
        public let imageUrl: String?
        public init(id: String, imageUrl: String?) {
            self.id = id
            self.imageUrl = imageUrl
        }

        var photoURL: String? {
            guard let url = imageUrl?.trimmingCharacters(in: .whitespaces), !url.isEmpty else { return nil }
            return url
        }
    }

    public var revision: Int
    public var entries: [String: Entry]

    public init(revision: Int, entries: [String: Entry] = [:]) {
        self.revision = revision
        self.entries = entries
    }

    /// Keeps only the entries still valid for these products (the current sin-código
    /// list) and returns the ones to index next, in the given order. A product with no
    /// photo isn't queued; it can still match on text.
    public func refreshed(for products: [Ref], revision: Int) -> (index: FeatureIndex, queue: [Ref]) {
        var index = FeatureIndex(revision: revision)
        var queue: [Ref] = []
        for product in products {
            guard let url = product.photoURL else { continue }
            if revision == self.revision, let entry = entries[product.id], entry.imageUrl == url {
                index.entries[product.id] = entry
            } else {
                queue.append(product)
            }
        }
        return (index, queue)
    }

    public mutating func insert(_ vector: [Float], for product: Ref) {
        guard let url = product.photoURL else { return }
        entries[product.id] = Entry(imageUrl: url, vector: vector)
    }

    public func vector(for id: String) -> [Float]? {
        entries[id]?.vector
    }
}
