import Foundation
import Testing
@testable import FarmaciaKit

/// GET /products/sync: pages of changed rows and removed ids, an opaque cursor, hasMore.
struct ProductSyncTests {
    struct Row: Identifiable, Equatable, Sendable { let id: String; let name: String }

    typealias Page = ProductSyncPage<Row>

    /// A fake server: answers each request with the next page, recording the cursor it was sent.
    final class Server: @unchecked Sendable {
        var pages: [Result<Page, Error>]
        var sentCursors: [String?] = []
        init(_ pages: [Result<Page, Error>]) { self.pages = pages }
        func fetch(_ cursor: String?) async throws -> Page {
            sentCursors.append(cursor)
            return try pages.removeFirst().get()
        }
    }

    func page(_ rows: [Row] = [], removed: [String] = [], cursor: String, hasMore: Bool = false) -> Result<Page, Error> {
        .success(Page(rows: rows, removedIds: removed, cursor: cursor, hasMore: hasMore))
    }

    func sorted(_ rows: [Row]) -> [Row] { rows.sorted { $0.id < $1.id } }

    let a = Row(id: "a", name: "Aspirina"), b = Row(id: "b", name: "Bonadoxina")

    @Test("given no stored cursor and two pages, should walk both, sending the first page's cursor, and report a full walk ending on the last cursor")
    func fullWalk() async throws {
        let server = Server([page([a], cursor: "c1", hasMore: true), page([b], cursor: "c2")])
        let result = try await ProductSync.run(from: nil, fetch: server.fetch)
        #expect(server.sentCursors == [nil, "c1"])
        #expect(sorted(result.upserts) == [a, b])
        #expect(result.cursor == "c2")
        #expect(result.isFullWalk)
    }

    @Test("given a stored cursor, should start from it and not be a full walk")
    func delta() async throws {
        let server = Server([page([a], cursor: "c2")])
        let result = try await ProductSync.run(from: "c1", fetch: server.fetch)
        #expect(server.sentCursors == ["c1"])
        #expect(!result.isFullWalk)
    }

    @Test("given a product changed then removed, one removed then re-added, and one sent twice, the last page each appears on should win")
    func lastWins() async throws {
        let a2 = Row(id: "a", name: "Aspirina 500")
        let c = Row(id: "c", name: "Cafiaspirina")
        let server = Server([
            page([a, c], removed: ["b"], cursor: "c2", hasMore: true),
            page([b, a2], cursor: "c3", hasMore: true),
            page(removed: ["c"], cursor: "c4"),
        ])
        let result = try await ProductSync.run(from: "c1", fetch: server.fetch)
        #expect(sorted(result.upserts) == [a2, b])
        #expect(result.removedIds == ["c"])
    }

    @Test("given the server rejects the stored cursor (400), should drop it and walk everything from no cursor")
    func rejectedCursor() async throws {
        let server = Server([.failure(NetworkError.httpError(statusCode: 400, message: "Cursor de sincronización inválido")),
                             page([a], cursor: "c9")])
        let result = try await ProductSync.run(from: "bad", fetch: server.fetch)
        #expect(server.sentCursors == ["bad", nil])
        #expect(result.isFullWalk)
        #expect(result.cursor == "c9")
    }

    @Test("given a 400 on a full walk, or any other failure, should throw (nothing to save; the stored cursor stays)",
          arguments: [(nil, 400), ("c1", 500)] as [(String?, Int)])
    func failures(stored: String?, status: Int) async {
        let server = Server([.failure(NetworkError.httpError(statusCode: status, message: nil)), page([a], cursor: "c9")])
        await #expect(throws: NetworkError.self) { try await ProductSync.run(from: stored, fetch: server.fetch) }
        #expect(server.sentCursors.count == 1)
    }

    @Test("given a delta, should delete only the removed ids the cache holds, keeping rows the delta didn't mention")
    func deltaDeletes() async throws {
        let server = Server([page([a], removed: ["b", "gone"], cursor: "c2")])
        let result = try await ProductSync.run(from: "c1", fetch: server.fetch)
        #expect(result.idsToDelete(cached: ["a", "b", "old"]) == ["b"])
    }

    @Test("given a full walk, should delete every cached id the walk didn't return (deleted before removals were recorded)")
    func fullWalkPrunes() async throws {
        let server = Server([page([a], cursor: "c1")])
        let result = try await ProductSync.run(from: nil, fetch: server.fetch)
        #expect(result.idsToDelete(cached: ["a", "b", "old"]) == ["b", "old"])
    }
}
