import Foundation
import Testing
@testable import FarmaciaKit

struct AuthErrorCodeTests {
    func body(_ json: String) -> Data { Data(json.utf8) }

    @Test("given a body with code SESSION_EXPIRED and any message, should resolve SESSION_EXPIRED")
    func codeWins() {
        #expect(AuthErrorCode.resolve(body: body(#"{"success":false,"message":"Tu sesión terminó","code":"SESSION_EXPIRED"}"#)) == .sessionExpired)
    }

    @Test("given an older server (no code), should resolve from the exact message",
          arguments: [
            ("Session expired", AuthErrorCode.sessionExpired),
            ("Invalid session", .sessionInvalid),
            ("Session token required", .sessionRequired),
            ("Invalid or deactivated device", .deviceInvalid),
            ("Device token required in Authorization header", .deviceRequired),
            ("PIN incorrecto", .pinInvalid),
            ("Correo o contraseña incorrectos", .credentialsInvalid),
            ("La cuenta del empleado está desactivada", .employeeInactive),
            ("Account not set up for device activation. Contact administrator.", .activationNotAllowed),
          ])
    func legacyMessage(message: String, expected: AuthErrorCode) {
        #expect(AuthErrorCode.resolve(body: body(#"{"success":false,"message":"\#(message)"}"#)) == expected)
    }

    @Test("given a code this app doesn't know, should fall back to the message")
    func unknownCode() {
        #expect(AuthErrorCode.resolve(body: body(#"{"success":false,"message":"Invalid session","code":"SOMETHING_NEW"}"#)) == .sessionInvalid)
    }

    @Test("given a message that only mentions 'device', should not resolve to a device code")
    func noSubstringMatch() {
        #expect(AuthErrorCode.resolve(body: body(#"{"success":false,"message":"Device not found"}"#)) == nil)
    }

    @Test("given no JSON body, should resolve nothing")
    func noBody() {
        #expect(AuthErrorCode.resolve(body: Data()) == nil)
    }
}
