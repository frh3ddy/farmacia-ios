import Foundation

// MARK: - Offline Replay
//
// What the offline queue may hold and replay. A queued write is sent again later,
// possibly after its first attempt already reached the server (a timeout), and with
// whatever session is current then. So only creates the server dedups by
// clientRequestId are queued. Auth and employee calls never are: their bodies carry
// PINs or passwords, and a replayed logout or location switch acts on the next
// employee's session. Edits and deletes aren't either (a late replay can overwrite
// newer data, or find the record gone).

public enum OfflineReplay {
    /// Creates whose body carries a clientRequestId the server matches on (in notice order).
    private static let replaySafePaths: [String] = [
        "/inventory/receive",
        "/inventory/adjustments",
        "/inventory/adjustments/damage",
        "/inventory/adjustments/theft",
        "/inventory/adjustments/expired",
        "/inventory/adjustments/found",
        "/inventory/adjustments/return",
        "/inventory/adjustments/count-correction",
        "/inventory/adjustments/write-off",
        "/expenses",
        "/products",
    ]
    private static let replaySafePOSTs = Set(replaySafePaths)

    public static func isReplaySafe(method: String, path: String) -> Bool {
        method == "POST" && replaySafePOSTs.contains(path)
    }

    /// Auth and employee calls: PINs, passwords, sessions. Never kept on disk.
    public static func carriesCredentials(method: String, path: String) -> Bool {
        path.hasPrefix("/auth/") || path == "/employees" || path.hasPrefix("/employees/")
    }

    /// What the failed-sync list calls a queued write.
    public static func label(method: String, path: String) -> String {
        guard isReplaySafe(method: method, path: path) else { return "\(method) \(path)" }
        if path.hasPrefix("/inventory/adjustments") { return "Ajuste de inventario" }
        switch path {
        case "/inventory/receive": return "Recepción de inventario"
        case "/expenses": return "Gasto"
        default: return "Producto nuevo"
        }
    }

    /// Replay only the employee who queued it, under their own session: never as
    /// someone else (wrong author, or refused for their role). Items from before
    /// items had an owner aren't replayed automatically.
    public static func shouldReplay(itemEmployeeId: String?, currentEmployeeId: String?) -> Bool {
        guard let itemEmployeeId, let currentEmployeeId else { return false }
        return itemEmployeeId == currentEmployeeId
    }

    /// Reintentar on a failed item is someone deciding "send this, as me": it becomes
    /// theirs (an item with no owner, or another employee's, would otherwise never replay).
    public static func ownerAfterRetry(itemEmployeeId: String?, retriedBy currentEmployeeId: String) -> String {
        currentEmployeeId
    }

    public enum FailureStep: Equatable, Sendable {
        /// Offline again, the session lapsed, or cancelled: leave it and the rest for the next flush.
        case stopAndKeep
        /// The server rejected it (or transient retries ran out): move it to the failed list.
        case markFailed
    }

    public static func afterFailure(_ error: Error) -> FailureStep {
        if NetworkError.isCancellation(error) { return .stopAndKeep }
        switch error as? NetworkError {
        case .networkUnavailable?, .timeout?, .sessionExpired?, .pinRequired?:
            return .stopAndKeep
        default:
            return .markFailed
        }
    }

    public enum StoredItemFate: Equatable, Sendable {
        case keep
        case markFailed(reason: String)
        case delete
    }

    /// One-time cleanup of items an older version queued: credentials go, writes that
    /// aren't safe to replay (or have no owner) wait in the failed list for a person.
    public static func cleanup(method: String, path: String, employeeId: String?, status: String) -> StoredItemFate {
        if carriesCredentials(method: method, path: path) { return .delete }
        guard status == "pending" else { return .keep }
        if !isReplaySafe(method: method, path: path) {
            return .markFailed(reason: "Ya no se sincroniza automáticamente: revísalo y reintenta o descarta.")
        }
        if employeeId == nil {
            return .markFailed(reason: "Pendiente de una versión anterior de la app: revísalo y reintenta o descarta.")
        }
        return .keep
    }

    /// The "Sin conexión" alert: built from the allowlist, so it can't promise more than queues.
    public static let offlineNotice: String = {
        var kinds: [String] = []
        for path in replaySafePaths {
            let kind = label(method: "POST", path: path).lowercased()
            if !kinds.contains(kind) { kinds.append(kind) }
        }
        return "Se guardan en este dispositivo y se sincronizan al volver la conexión: \(spanishList(kinds)). Los demás cambios necesitan conexión."
    }()

    /// The banner for other employees' writes waiting on this device ("inicie" for one, "inicien" for several).
    public static func othersWaitingText(_ names: [String]) -> String {
        "Cambios de \(spanishList(names)) se sincronizan cuando \(names.count == 1 ? "inicie" : "inicien") sesión"
    }

    /// "a", "a y b", "a, b y c".
    private static func spanishList(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " y " + items[items.count - 1]
    }

    /// Who a queued item belongs to, as the banner needs it.
    public struct Owner: Equatable, Sendable {
        public let id: String?
        public let name: String?
        public init(id: String?, name: String?) {
            self.id = id
            self.name = name
        }
    }

    /// Pending items: how many the logged-in employee's next flush sends, and who
    /// else has writes waiting on this device (each name once). An item with no owner
    /// waits for nobody: `cleanup` moves it to the failed list for review instead.
    public static func splitPending(_ owners: [Owner], currentEmployeeId: String?) -> (mine: Int, others: [String]) {
        let mine = owners.filter { shouldReplay(itemEmployeeId: $0.id, currentEmployeeId: currentEmployeeId) }.count
        let others = owners
            .filter { $0.id != nil && !shouldReplay(itemEmployeeId: $0.id, currentEmployeeId: currentEmployeeId) }
            .map { $0.name ?? "otro empleado" }
        return (mine, Array(Set(others)).sorted())
    }

    /// The failed list shows an employee their own items, plus ones with no owner
    /// (anyone may review those); another employee's wait for them.
    public static func showsFailed(itemEmployeeId: String?, currentEmployeeId: String?) -> Bool {
        itemEmployeeId == nil || itemEmployeeId == currentEmployeeId
    }
}
