import Testing
@testable import FarmaciaKit

struct SingleFlightTests {
    /// Counts calls and holds the first one open until `release()`. Later calls return at
    /// once, so a caller that missed joining the flight fails the call count instead of hanging.
    actor Server {
        private(set) var calls = 0
        private var waiting: [CheckedContinuation<Void, Never>] = []

        func call() async -> Int {
            calls += 1
            let n = calls
            if n == 1 { await withCheckedContinuation { waiting.append($0) } }
            return n
        }

        func release() {
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    struct Boom: Error {}

    /// Waits until the server has seen `n` calls.
    func until(_ server: Server, calls n: Int) async {
        while await server.calls < n { await Task.yield() }
    }

    @Test("given two concurrent refreshes, should call the server once and give both the same result")
    func coalesces() async throws {
        let flight = SingleFlight<Int>()
        let server = Server()

        let first = Task { try await flight.run { await server.call() } }
        await until(server, calls: 1)
        let second = Task { try await flight.run { await server.call() } }
        for _ in 0..<100 { await Task.yield() } // let the second caller reach the flight
        await server.release()

        #expect(try await first.value == 1)
        #expect(try await second.value == 1)
        #expect(await server.calls == 1)
    }

    @Test("given a refresh that finished, should start a new one on the next call")
    func runsAgainAfterward() async throws {
        let flight = SingleFlight<Int>()
        let server = Server()

        let first = Task { try await flight.run { await server.call() } }
        await until(server, calls: 1)
        await server.release()
        _ = try await first.value

        let second = try await flight.run { await server.call() }
        #expect(second == 2)
    }

    @Test("given a refresh that throws, should rethrow to every waiter")
    func rethrowsToEveryWaiter() async {
        let flight = SingleFlight<Int>()
        let server = Server()

        let first = Task { try await flight.run { _ = await server.call(); throw Boom() } }
        await until(server, calls: 1)
        let second = Task { try await flight.run { _ = await server.call(); throw Boom() } }
        for _ in 0..<100 { await Task.yield() }
        await server.release()

        await #expect(throws: Boom.self) { try await first.value }
        await #expect(throws: Boom.self) { try await second.value }
        #expect(await server.calls == 1)
    }
}
