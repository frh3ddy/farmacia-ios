import Testing
@testable import FarmaciaKit

struct SaveOutcomeTests {
    @Test("given a save queued while offline, should count as saved")
    func queuedIsSaved() {
        #expect(SaveOutcome(error: NetworkError.queuedForSync, fallback: "x") == .saved)
    }

    @Test("given the API rejects the save, should show its reason")
    func showsServerReason() {
        let error = NetworkError.httpError(statusCode: 400, message: "Indica el costo unitario")
        #expect(SaveOutcome(error: error, fallback: "Error al crear ajuste") == .failed("Indica el costo unitario"))
    }

    @Test("given a failure that isn't a network error, should show the fallback")
    func otherErrorShowsFallback() {
        struct Boom: Error {}
        #expect(SaveOutcome(error: Boom(), fallback: "Error al crear ajuste") == .failed("Error al crear ajuste"))
    }
}
