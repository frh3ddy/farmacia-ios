import Foundation
import SwiftData

// MARK: - Queued Request
//
// A mutating API call (POST/PATCH/PUT/DELETE) that failed because the device
// was offline, persisted so it can be replayed once connectivity returns.
// For delta-style writes (adjustments, receivings, expenses) the request body
// already carries a clientRequestId — matched by a @unique column on the API
// side — so a replay can never double-apply, even if the original attempt
// actually reached the server before its response was lost.

@Model
final class QueuedRequest: Identifiable {
    @Attribute(.unique) var id: UUID
    var method: String
    var path: String
    var bodyData: Data?
    var summary: String
    var queuedAt: Date
    var status: String // "pending" | "failed"
    var lastError: String?

    init(method: String, path: String, bodyData: Data?, summary: String) {
        self.id = UUID()
        self.method = method
        self.path = path
        self.bodyData = bodyData
        self.summary = summary
        self.queuedAt = Date()
        self.status = "pending"
    }
}
