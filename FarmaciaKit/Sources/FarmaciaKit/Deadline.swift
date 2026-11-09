import Foundation
import os

// MARK: - Deadline
//
// Apple Intelligence gets a fixed time to name a new product's photo. A task
// group can't enforce that: it waits for every child to finish, so work that
// only notices cancellation late (a model encoding an image) would overrun.

public enum Deadline {
    /// The work's result, or nil once `limit` passes, without waiting for the
    /// work to notice it was cancelled (a task group would wait for it). A
    /// cancelled caller (a new photo) also gets nil right away.
    public static func within<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async -> T?) async -> T? {
        // Whichever comes first (the answer, the timeout, cancellation) wins; an
        // answer that arrives before the continuation is stored is kept for it.
        let state = OSAllocatedUnfairLock<RaceState<T>>(initialState: .waiting)
        let finish: @Sendable (T?) -> Void = { value in
            let waiting = state.withLock { state -> CheckedContinuation<T?, Never>? in
                switch state {
                case .waiting: state = .done(value); return nil
                case .suspended(let continuation): state = .done(value); return continuation
                case .done: return nil
                }
            }
            waiting?.resume(returning: value)
        }
        let worker = Task { finish(await work()) }
        let timer = Task {
            try? await Task.sleep(for: limit)
            worker.cancel()
            finish(nil)
        }
        defer { timer.cancel() }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let early = state.withLock { state -> T?? in
                    if case .done(let value) = state { return .some(value) }
                    state = .suspended(continuation)
                    return nil
                }
                if let early { continuation.resume(returning: early) }
            }
        } onCancel: {
            worker.cancel()
            finish(nil)
        }
    }

    private enum RaceState<T> {
        case waiting
        case suspended(CheckedContinuation<T?, Never>)
        case done(T?)
    }
}
