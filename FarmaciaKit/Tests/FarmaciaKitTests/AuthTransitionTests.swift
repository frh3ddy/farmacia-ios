import Testing
@testable import FarmaciaKit

struct AuthTransitionTests {
    @Test("given SESSION_EXPIRED on a request sent with the current token, should end the session",
          arguments: [AuthErrorCode.sessionExpired, .sessionInvalid, .sessionRequired])
    func endsSession(code: AuthErrorCode) {
        #expect(AuthTransition.after(code, requestSessionToken: "st_1", currentSessionToken: "st_1") == .endSession)
    }

    @Test("given a session refusal for a token that has since been rotated, should do nothing")
    func staleToken() {
        #expect(AuthTransition.after(.sessionInvalid, requestSessionToken: "st_old", currentSessionToken: "st_new") == .none)
    }

    @Test("given a session refusal when already logged out, should do nothing")
    func alreadyLoggedOut() {
        #expect(AuthTransition.after(.sessionExpired, requestSessionToken: nil, currentSessionToken: nil) == .none)
    }

    @Test("given an employee deactivated mid-session, should end the session")
    func employeeInactiveInSession() {
        #expect(AuthTransition.after(.employeeInactive, requestSessionToken: "st_1", currentSessionToken: "st_1") == .endSession)
    }

    @Test("given a deactivated employee at device activation (no session), should do nothing")
    func employeeInactiveAtActivation() {
        #expect(AuthTransition.after(.employeeInactive, requestSessionToken: nil, currentSessionToken: nil) == .none)
    }

    @Test("given a device refusal, should deactivate the device",
          arguments: [AuthErrorCode.deviceInvalid, .deviceRequired])
    func deactivates(code: AuthErrorCode) {
        #expect(AuthTransition.after(code, requestSessionToken: "st_1", currentSessionToken: "st_1") == .deactivateDevice)
    }

    @Test("given a refusal that isn't about the session or device, should do nothing",
          arguments: [AuthErrorCode.pinInvalid, .tooManyAttempts, .credentialsInvalid, .activationNotAllowed])
    func otherRefusals(code: AuthErrorCode?) {
        #expect(AuthTransition.after(code, requestSessionToken: "st_1", currentSessionToken: "st_1") == .none)
    }

    @Test("given no auth code at all, should do nothing")
    func noCode() {
        #expect(AuthTransition.after(nil, requestSessionToken: "st_1", currentSessionToken: "st_1") == .none)
    }
}
