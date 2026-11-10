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
        case .unitCostRequired(let message): return "unitCostRequired(\(message))"
        default: return "other"
        }
    }

    @Test("given NestJS's default 400 body (no success field), should show its message")
    func nestDefaultBadRequest() {
        let body = #"{"message":"La cantidad debe ser un número entero distinto de cero","error":"Bad Request","statusCode":400}"#
        #expect(describe(from(400, body)) == "httpError(400, La cantidad debe ser un número entero distinto de cero)")
    }

    @Test("given 400 with code UNIT_COST_REQUIRED, should ask for the unit cost")
    func unitCostRequired() {
        let body = #"{"success":false,"code":"UNIT_COST_REQUIRED","message":"Indica el costo unitario"}"#
        #expect(describe(from(400, body)) == "unitCostRequired(Indica el costo unitario)")
    }

    @Test("given an older API's exact cost message with no code, should still ask for the unit cost")
    func unitCostRequiredLegacy() {
        let body = #"{"message":"Indica el costo unitario: este producto no tiene un costo anterior registrado.","error":"Bad Request","statusCode":400}"#
        #expect(describe(from(400, body)) == "unitCostRequired(Indica el costo unitario: este producto no tiene un costo anterior registrado.)")
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

/// Transfer refusals keep their code and the item they name, so the screen can say
/// which product failed (a batch stops at its first failing item).
struct NetworkErrorRefusalTests {
    private func refusal(_ status: Int, _ json: String) -> NetworkError.Refusal? {
        if case .refused(let refusal)? = NetworkError.from(statusCode: status, body: Data(json.utf8)) { return refusal }
        return nil
    }

    @Test("given a 400 INSUFFICIENT_STOCK, should keep the code, product and what's available")
    func insufficientStock() throws {
        let body = #"{"success":false,"code":"INSUFFICIENT_STOCK","message":"No hay suficientes existencias","productId":"asp","requested":5,"available":4}"#
        let refusal = try #require(refusal(400, body))
        #expect(refusal == .init(code: "INSUFFICIENT_STOCK", message: "No hay suficientes existencias", productId: "asp", available: 4))
    }

    @Test("given a 403 RECEIVE_ON_SEND_NOT_ALLOWED, should keep the code instead of a bare unauthorized")
    func receiveOnSendForbidden() throws {
        let body = #"{"success":false,"code":"RECEIVE_ON_SEND_NOT_ALLOWED","message":"No tienes acceso a la sucursal de destino: envíala para confirmar al llegar"}"#
        #expect(try #require(refusal(403, body)).code == "RECEIVE_ON_SEND_NOT_ALLOWED")
    }

    @Test("given the newer transfer codes, should keep them too", arguments: ["INVALID_ITEM", "LOCATION_NOT_CUT_OVER", "NO_ITEMS"])
    func newerCodes(code: String) {
        #expect(refusal(400, #"{"success":false,"code":"\#(code)","message":"x"}"#)?.code == code)
    }

    @Test("given a 409 CLIENT_REQUEST_ID_REUSED, should keep the code")
    func requestIdReused() {
        #expect(refusal(409, #"{"success":false,"code":"CLIENT_REQUEST_ID_REUSED","message":"x"}"#)?.code == "CLIENT_REQUEST_ID_REUSED")
    }

    @Test("given a refusal, should describe itself with the server's message")
    func describesWithMessage() {
        let error = NetworkError.refused(.init(code: "SAME_LOCATION", message: "Elige otra sucursal", productId: nil, available: nil))
        #expect(error.errorDescription == "Elige otra sucursal")
    }

    @Test("given a 403 with no code, should stay unauthorized")
    func plainForbidden() {
        if case .unauthorized? = NetworkError.from(statusCode: 403, body: Data(#"{"message":"No tienes acceso a esta sucursal"}"#.utf8)) {} else {
            Issue.record("expected unauthorized")
        }
    }

    @Test("given a 400 with a code outside transfers, should stay an httpError", arguments: ["SOMETHING_ELSE"])
    func otherCodes(code: String) {
        if case .httpError(400, "x")? = NetworkError.from(statusCode: 400, body: Data(#"{"code":"\#(code)","message":"x"}"#.utf8)) {} else {
            Issue.record("expected httpError")
        }
    }
}
