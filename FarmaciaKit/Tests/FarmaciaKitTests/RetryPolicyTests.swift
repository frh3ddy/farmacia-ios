import Testing
@testable import FarmaciaKit

struct RetryPolicyTests {
    final class Counter: @unchecked Sendable { var calls = 0 }

    @Test("given a server error that recovers, should retry and return the value")
    func retriesServerError() async throws {
        let counter = Counter()
        let value = try await RetryPolicy.withBackoff(baseDelay: 0) {
            counter.calls += 1
            if counter.calls < 3 { throw NetworkError.serverError(message: "boom") }
            return 42
        }
        #expect(value == 42)
        #expect(counter.calls == 3)
    }

    @Test("given a server error every time, should give up after maxAttempts")
    func givesUp() async {
        let counter = Counter()
        await #expect(throws: NetworkError.self) {
            try await RetryPolicy.withBackoff(maxAttempts: 3, baseDelay: 0) {
                counter.calls += 1
                throw NetworkError.serverError(message: "boom")
            }
        }
        #expect(counter.calls == 3)
    }

    @Test("given the caller is cancelled during the backoff, should stop retrying")
    func stopsWhenCancelled() async {
        let counter = Counter()
        let task = Task {
            try await RetryPolicy.withBackoff(baseDelay: 60) {
                counter.calls += 1
                throw NetworkError.serverError(message: "boom")
            }
        }
        while counter.calls == 0 { await Task.yield() }
        task.cancel()
        _ = await task.result
        #expect(counter.calls == 1)
    }

    @Test("given no network, should not retry (offline queue handles it)")
    func doesNotRetryConnectivity() async {
        let counter = Counter()
        await #expect(throws: NetworkError.self) {
            try await RetryPolicy.withBackoff(baseDelay: 0) {
                counter.calls += 1
                throw NetworkError.networkUnavailable
            }
        }
        #expect(counter.calls == 1)
    }
}
