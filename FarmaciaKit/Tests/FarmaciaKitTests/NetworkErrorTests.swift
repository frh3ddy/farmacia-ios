import Foundation
import Testing
@testable import FarmaciaKit

struct NetworkErrorTests {
    @Test("given an API error body, should prefer message over error code",
          arguments: [
            (#"{"success":false,"error":"BAD","message":"PIN incorrecto"}"#, "PIN incorrecto"),
            (#"{"success":false,"error":"BAD"}"#, "BAD"),
            (#"{"success":false}"#, "Ocurrió un error desconocido"),
          ])
    func displayMessage(json: String, expected: String) throws {
        let body = try JSONDecoder().decode(APIErrorResponse.self, from: Data(json.utf8))
        #expect(body.displayMessage == expected)
    }

    @Test("given an HTTP error with a server message, should show that message")
    func httpErrorUsesMessage() {
        #expect(NetworkError.httpError(statusCode: 400, message: "Stock insuficiente").errorDescription == "Stock insuficiente")
    }

    @Test("given auth/connectivity errors, should be recoverable; decoding should not")
    func recoverability() {
        #expect(NetworkError.sessionExpired.isRecoverable)
        #expect(NetworkError.networkUnavailable.isRecoverable)
        #expect(!NetworkError.invalidURL.isRecoverable)
    }
}
