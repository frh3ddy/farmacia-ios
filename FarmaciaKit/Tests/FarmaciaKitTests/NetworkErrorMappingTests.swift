import Foundation
import Testing
@testable import FarmaciaKit

/// Maps HTTP responses the way farmacia-ops actually answers them.
struct NetworkErrorMappingTests {
    func from(_ status: Int, _ json: String) -> NetworkError? {
        NetworkError.from(statusCode: status, body: Data(json.utf8))
    }

    /// The case name and message, so errors (which hold non-Equatable values) compare in tests.
    func describe(_ error: NetworkError?) -> String {
        switch error {
        case nil: return "nil"
        case .httpError(let status, let message): return "httpError(\(status), \(message ?? "nil"))"
        case .accountLocked(let until): return "accountLocked(\(until.map { ISO8601DateFormatter().string(from: $0) } ?? "nil"))"
        case .serverError(let message): return "serverError(\(message))"
        case .sessionExpired: return "sessionExpired"
        case .deviceNotActivated: return "deviceNotActivated"
        case .unauthorized: return "unauthorized"
        default: return "other"
        }
    }

    @Test("given 401 'PIN incorrecto', should keep the server message")
    func wrongPIN() {
        #expect(describe(from(401, #"{"success":false,"message":"PIN incorrecto","code":"PIN_INVALID"}"#)) == "httpError(401, PIN incorrecto)")
    }

    @Test("given 429 TOO_MANY_ATTEMPTS with lockedUntil in milliseconds, should be locked until that time")
    func lockout() {
        let json = #"{"success":false,"message":"Demasiados intentos fallidos. Intenta de nuevo en 15 minutos.","code":"TOO_MANY_ATTEMPTS","lockedUntil":"2026-11-15T18:30:00.000Z"}"#
        #expect(describe(from(429, json)) == "accountLocked(2026-11-15T18:30:00Z)")
    }

    @Test("given a session refusal from a new or old server, should be sessionExpired",
          arguments: [
            #"{"success":false,"message":"Session expired","code":"SESSION_EXPIRED"}"#,
            #"{"success":false,"message":"Invalid session","code":"SESSION_INVALID"}"#,
            #"{"success":false,"message":"Session token required"}"#,
            #"{"success":false,"message":"Session expired"}"#,
          ])
    func session(json: String) {
        #expect(describe(from(401, json)) == "sessionExpired")
    }

    @Test("given a device refusal, should be deviceNotActivated",
          arguments: [
            #"{"success":false,"message":"Invalid or deactivated device","code":"DEVICE_INVALID"}"#,
            #"{"success":false,"message":"Device token required in Authorization header"}"#,
          ])
    func device(json: String) {
        #expect(describe(from(401, json)) == "deviceNotActivated")
    }

    @Test("given 'Account not set up for device activation…' with no code, should keep the message, not deviceNotActivated")
    func activationNotAllowed() {
        let json = #"{"success":false,"message":"Account not set up for device activation. Contact administrator."}"#
        #expect(describe(from(401, json)) == "httpError(401, Account not set up for device activation. Contact administrator.)")
    }

    @Test("given 401 with no body, should be unauthorized")
    func bare401() {
        #expect(describe(from(401, "")) == "unauthorized")
    }

    @Test("given today's other statuses, should map as before",
          arguments: [
            (200, #"{"success":true}"#, "nil"),
            (403, #"{"success":false,"message":"No tienes acceso a esta sucursal"}"#, "unauthorized"),
            (400, #"{"success":false,"message":"quantity is required"}"#, "httpError(400, quantity is required)"),
            (404, "", "httpError(404, nil)"),
            (500, #"{"success":false,"message":"boom"}"#, "serverError(boom)"),
            (502, "", "serverError(Error interno del servidor)"),
          ])
    func unchanged(status: Int, json: String, expected: String) {
        #expect(describe(from(status, json)) == expected)
    }
}
