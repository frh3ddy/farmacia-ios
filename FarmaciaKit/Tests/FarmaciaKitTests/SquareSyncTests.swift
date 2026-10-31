import Testing
@testable import FarmaciaKit

struct SquareSyncTests {
    @Test("given squareSynced false and squareSyncError \"LOCATION_NOT_FOUND\", should count as a failed sync")
    func errorIsFailed() {
        #expect(SquareSync.failed(synced: false, error: "LOCATION_NOT_FOUND"))
    }

    @Test("given squareSynced true with a leftover error, or never attempted, should not count as failed",
          arguments: [(true, "LOCATION_NOT_FOUND"), (false, nil), (nil, nil)] as [(Bool?, String?)])
    func notFailed(synced: Bool?, error: String?) {
        #expect(!SquareSync.failed(synced: synced, error: error))
    }

    @Test("given a manager, should not offer the retry; given the owner, should", arguments: [(false, false), (true, true)])
    func ownerOnly(isOwner: Bool, offered: Bool) {
        #expect(SquareSync.canRetry(isOwner: isOwner) == offered)
    }

    @Test("given a retry answered with synced false and error \"LOCATION_NOT_FOUND\", should fail with the reason")
    func retryFailedWithReason() {
        #expect(SquareSync.RetryOutcome(synced: false, error: "LOCATION_NOT_FOUND")
                == .failed("No se pudo sincronizar con Square: LOCATION_NOT_FOUND"))
    }

    @Test("given synced true, should be synced; given synced false with no error, should fail without a reason")
    func retrySyncedAndNoReason() {
        #expect(SquareSync.RetryOutcome(synced: true, error: nil) == .synced)
        #expect(SquareSync.RetryOutcome(synced: false, error: nil) == .failed("No se pudo sincronizar con Square"))
    }
}
