import Foundation
import Testing
@testable import FarmaciaKit

struct FeatureIndexTests {
    typealias Ref = FeatureIndex.Ref
    static let v: [Float] = [0.6, 0.8]

    static func index(_ entries: [String: FeatureIndex.Entry], revision: Int = 2) -> FeatureIndex {
        FeatureIndex(revision: revision, entries: entries)
    }

    @Test("given an entry whose photo URL changed, should drop it and queue the product")
    func urlChanged() {
        let old = Self.index(["p1": .init(imageUrl: "https://img/old.jpg", vector: Self.v)])
        let (index, queue) = old.refreshed(for: [Ref(id: "p1", imageUrl: "https://img/new.jpg")], revision: 2)
        #expect(index.entries["p1"] == nil)
        #expect(queue == [Ref(id: "p1", imageUrl: "https://img/new.jpg")])
    }

    @Test("given an entry with the same URL and revision, should keep it and not queue it")
    func current() {
        let old = Self.index(["p1": .init(imageUrl: "https://img/a.jpg", vector: Self.v)])
        let (index, queue) = old.refreshed(for: [Ref(id: "p1", imageUrl: "https://img/a.jpg")], revision: 2)
        #expect(index.entries["p1"]?.vector == Self.v)
        #expect(queue.isEmpty)
    }

    @Test("given a new Vision revision, should drop every entry, queue them all and take the new revision")
    func revisionChanged() {
        let old = Self.index(["p1": .init(imageUrl: "https://img/a.jpg", vector: Self.v),
                              "p2": .init(imageUrl: "https://img/b.jpg", vector: Self.v)], revision: 1)
        let refs = [Ref(id: "p1", imageUrl: "https://img/a.jpg"), Ref(id: "p2", imageUrl: "https://img/b.jpg")]
        let (index, queue) = old.refreshed(for: refs, revision: 2)
        #expect(index.entries.isEmpty)
        #expect(index.revision == 2)
        #expect(queue == refs)
    }

    @Test("given a product no longer sin código (a barcode was added), should drop its entry")
    func leftTheList() {
        let old = Self.index(["gone": .init(imageUrl: "https://img/a.jpg", vector: Self.v)])
        let (index, queue) = old.refreshed(for: [], revision: 2)
        #expect(index.entries.isEmpty)
        #expect(queue.isEmpty)
    }

    @Test("given a product with no photo URL, should not queue it and drop any old entry")
    func noPhoto() {
        let old = Self.index(["p1": .init(imageUrl: "https://img/a.jpg", vector: Self.v)])
        let (index, queue) = old.refreshed(for: [Ref(id: "p1", imageUrl: nil), Ref(id: "p2", imageUrl: "  ")], revision: 2)
        #expect(index.entries.isEmpty)
        #expect(queue.isEmpty)
    }

    @Test("given a product indexed, should return its vector for ranking")
    func inserting() {
        var index = Self.index([:])
        index.insert(Self.v, for: Ref(id: "p1", imageUrl: "https://img/a.jpg"))
        #expect(index.vector(for: "p1") == Self.v)
        #expect(index.vector(for: "p2") == nil)
    }

    @Test("given a saved index, should decode back to the same value")
    func roundTrip() throws {
        let index = Self.index(["p1": .init(imageUrl: "https://img/a.jpg", vector: Self.v)])
        let decoded = try JSONDecoder().decode(FeatureIndex.self, from: JSONEncoder().encode(index))
        #expect(decoded == index)
    }
}
