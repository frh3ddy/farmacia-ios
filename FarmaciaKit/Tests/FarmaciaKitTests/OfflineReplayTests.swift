import Foundation
import Testing
@testable import FarmaciaKit

/// What the offline queue may hold and replay. Only creates the server dedups by
/// clientRequestId are safe; auth and employee calls carry PINs or passwords and
/// act on whoever's session is current at replay time.
struct OfflineReplayTests {
    @Test("given an auth call (PIN login, logout, device activation, switch location, setup), should not be replay-safe",
          arguments: ["/auth/pin", "/auth/pin/refresh", "/auth/logout", "/auth/device/activate", "/auth/switch-location",
                      "/auth/setup/initial", "/auth/device/d1/deactivate"])
    func auth(path: String) {
        #expect(!OfflineReplay.isReplaySafe(method: "POST", path: path))
        #expect(OfflineReplay.carriesCredentials(method: "POST", path: path))
    }

    @Test("given an edit, delete, employee or maintenance write, should not be replay-safe",
          arguments: [("POST", "/employees"), ("POST", "/employees/e1/pin"), ("PUT", "/employees/e1"),
                      ("PATCH", "/products/p1/price"), ("PUT", "/expenses/x1"), ("DELETE", "/expenses/x1"),
                      ("PUT", "/labor/shifts/s1"), ("DELETE", "/labor/shifts/s1"),
                      ("POST", "/inventory/adjustments/a1/retry-square-sync"), ("POST", "/inventory/receive/r1/retry-square-sync"),
                      ("POST", "/products/sync-to-square"), ("POST", "/suppliers")])
    func unsafe(method: String, path: String) {
        #expect(!OfflineReplay.isReplaySafe(method: method, path: path))
    }

    @Test("given a create the server dedups by clientRequestId, should be replay-safe",
          arguments: ["/inventory/receive", "/inventory/adjustments", "/inventory/adjustments/damage", "/inventory/adjustments/theft",
                      "/inventory/adjustments/expired", "/inventory/adjustments/found", "/inventory/adjustments/return",
                      "/inventory/adjustments/count-correction", "/inventory/adjustments/write-off", "/expenses", "/products"])
    func safe(path: String) {
        #expect(OfflineReplay.isReplaySafe(method: "POST", path: path))
        #expect(!OfflineReplay.carriesCredentials(method: "POST", path: path))
    }

    @Test("given the same path with another method, should not be replay-safe")
    func methodMatters() {
        #expect(!OfflineReplay.isReplaySafe(method: "PUT", path: "/expenses"))
        #expect(!OfflineReplay.isReplaySafe(method: "GET", path: "/products"))
    }

    @Test("given a replay-safe write, should label it for staff",
          arguments: [("/inventory/adjustments/damage", "Ajuste de inventario"), ("/inventory/adjustments", "Ajuste de inventario"),
                      ("/inventory/receive", "Recepción de inventario"), ("/expenses", "Gasto"), ("/products", "Producto nuevo")])
    func label(path: String, expected: String) {
        #expect(OfflineReplay.label(method: "POST", path: path) == expected)
    }

    @Test("given anything else (e.g. an item queued by an older version), should fall back to method and path")
    func labelFallback() {
        #expect(OfflineReplay.label(method: "PATCH", path: "/products/p1/price") == "PATCH /products/p1/price")
    }

    // MARK: Who a queued write belongs to

    @Test("given an item queued by A, should replay it only while A is logged in")
    func owner() {
        #expect(!OfflineReplay.shouldReplay(itemEmployeeId: "a", currentEmployeeId: "b"))
        #expect(OfflineReplay.shouldReplay(itemEmployeeId: "a", currentEmployeeId: "a"))
        #expect(!OfflineReplay.shouldReplay(itemEmployeeId: "a", currentEmployeeId: nil))
    }

    @Test("given an item with no employee (queued before this update), should not replay it")
    func noOwner() {
        #expect(!OfflineReplay.shouldReplay(itemEmployeeId: nil, currentEmployeeId: "a"))
    }

    @Test("given a failed item with no owner, or A's, retried by B, should become B's and replayable by B",
          arguments: [nil, "a"] as [String?])
    func retryClaims(itemEmployeeId: String?) {
        let owner = OfflineReplay.ownerAfterRetry(itemEmployeeId: itemEmployeeId, retriedBy: "b")
        #expect(owner == "b")
        #expect(OfflineReplay.shouldReplay(itemEmployeeId: owner, currentEmployeeId: "b"))
    }

    // MARK: A replay that failed

    @Test("given offline, a timeout, a lapsed session or a cancellation while flushing, should stop and keep the item pending",
          arguments: [NetworkError.networkUnavailable as Error, NetworkError.timeout, NetworkError.sessionExpired, NetworkError.pinRequired, NetworkError.cancelled, CancellationError()])
    func stopAndKeep(error: Error) {
        #expect(OfflineReplay.afterFailure(error) == .stopAndKeep)
    }

    @Test("given the server rejected it, or transient retries ran out, should mark it failed",
          arguments: [NetworkError.httpError(statusCode: 400, message: "bad"), .httpError(statusCode: 409, message: nil),
                      .serverError(message: "boom"), .decodingError(URLError(.badServerResponse))] as [Error])
    func markFailed(error: Error) {
        #expect(OfflineReplay.afterFailure(error) == .markFailed)
    }

    // MARK: Items already on a device from an older version

    @Test("given a stored item carrying credentials, cleanup should delete it, pending or failed",
          arguments: [("POST", "/auth/pin", "pending"), ("POST", "/employees", "failed"), ("POST", "/auth/logout", "pending")])
    func cleanupDeletesCredentials(method: String, path: String, status: String) {
        #expect(OfflineReplay.cleanup(method: method, path: path, employeeId: "a", status: status) == .delete)
    }

    @Test("given a pending item that isn't replay-safe or has no owner, cleanup should mark it failed for review")
    func cleanupMarksFailed() {
        let unsafe = OfflineReplay.cleanup(method: "PATCH", path: "/products/p1/price", employeeId: "a", status: "pending")
        let ownerless = OfflineReplay.cleanup(method: "POST", path: "/expenses", employeeId: nil, status: "pending")
        guard case .markFailed(let unsafeReason) = unsafe, case .markFailed(let ownerlessReason) = ownerless else {
            Issue.record("expected markFailed, got \(unsafe) and \(ownerless)")
            return
        }
        #expect(unsafeReason.contains("revísalo"))
        #expect(ownerlessReason.contains("versión anterior"))
    }

    @Test("given a replay-safe item with an owner, or an already failed non-credential item, cleanup should keep it",
          arguments: [("POST", "/expenses", "a", "pending"), ("PATCH", "/products/p1/price", "a", "failed")] as [(String, String, String?, String)])
    func cleanupKeeps(method: String, path: String, employeeId: String?, status: String) {
        #expect(OfflineReplay.cleanup(method: method, path: path, employeeId: employeeId, status: status) == .keep)
    }
}
