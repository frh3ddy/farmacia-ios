import UIKit

// MARK: - Background Task Protection
//
// Wraps a sequential async operation (e.g. posting N items one request at a
// time) in a UIKit background task so it can finish even if the user
// backgrounds the app mid-batch. Without this, iOS suspends the process at
// the end of its normal execution window and the loop just stops silently —
// no error, and no record of which items made it through.

func withBackgroundTask<T>(
    name: String,
    _ body: () async -> T
) async -> T {
    var taskId: UIBackgroundTaskIdentifier = .invalid
    taskId = UIApplication.shared.beginBackgroundTask(withName: name) {
        UIApplication.shared.endBackgroundTask(taskId)
        taskId = .invalid
    }

    let result = await body()

    if taskId != .invalid {
        UIApplication.shared.endBackgroundTask(taskId)
    }

    return result
}
