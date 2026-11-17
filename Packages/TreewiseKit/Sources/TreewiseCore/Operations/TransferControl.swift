import Foundation

/// Pauses, resumes and stops one transfer (ADR 0026). The copying side asks
/// `waitWhilePaused()` before each file and while a file copies, on whatever
/// thread copies; the window pauses, resumes and stops.
///
/// `@unchecked Sendable` as ADR 0026 allows: its state is only read and
/// written while `condition` is locked, and Core may use only Foundation.
public final class TransferControl: @unchecked Sendable {
    private let condition = NSCondition()
    private var paused = false
    private var stopped = false
    /// The tasks in `untilResumed()`, resumed once the transfer is resumed or stopped.
    private var waiters: [CheckedContinuation<Void, Never>] = []
    /// What `whileRunning(onStop:run:)` runs on a stop, by the call that is running.
    private var stopActions: [UUID: @Sendable () -> Void] = [:]

    /// Creates a control for a transfer that runs.
    public init() {}

    /// Whether the transfer is paused.
    public var isPaused: Bool {
        condition.withLock { paused }
    }

    /// Whether the transfer was stopped; it does not go on after that.
    public var isStopped: Bool {
        condition.withLock { stopped }
    }

    /// Holds the transfer at its next file or block.
    public func pause() {
        condition.withLock { paused = true }
    }

    /// Lets a paused transfer go on.
    public func resume() {
        let waiting = condition.withLock {
            paused = false
            condition.broadcast()
            return takeWaiters()
        }
        for waiter in waiting { waiter.resume() }
    }

    /// Stops the transfer, also while it is paused.
    public func stop() {
        let (waiting, actions) = condition.withLock {
            stopped = true
            condition.broadcast()
            return (takeWaiters(), Array(stopActions.values))
        }
        for waiter in waiting { waiter.resume() }
        for action in actions { action() }
    }

    /// Runs `body`, and `onStop` once if the transfer is stopped while it runs: at once
    /// when it already was. It is for a wait the transfer cannot check itself, such as a
    /// file coordinator waiting for a provider's download (ADR 0122). `onStop` runs on the
    /// thread that stops, outside the control's lock; a stop as `body`
    /// ends may still run it, so it must be harmless then.
    @discardableResult
    public func whileRunning<Value>(
        onStop: @escaping @Sendable () -> Void, run body: () throws -> Value
    ) rethrows -> Value {
        let key = UUID()
        let isStopped = condition.withLock {
            if !stopped { stopActions[key] = onStop }
            return stopped
        }
        if isStopped { onStop() }
        defer { _ = condition.withLock { stopActions.removeValue(forKey: key) } }
        return try body()
    }

    /// Hands out the waiting tasks and empties the list. Precondition: `condition` is locked.
    private func takeWaiters() -> [CheckedContinuation<Void, Never>] {
        defer { waiters = [] }
        return waiters
    }

    /// Blocks the calling thread while the transfer is paused.
    ///
    /// - Returns: `false` when the transfer is stopped, so the copy must end.
    public func waitWhilePaused() -> Bool {
        condition.withLock {
            while paused && !stopped { condition.wait() }
            return !stopped
        }
    }

    /// Waits without blocking a thread while the transfer is paused, for
    /// providers that do not copy on a thread of their own; the task is suspended
    /// until `resume()` or `stop()`, not woken again and again.
    ///
    /// - Returns: `false` when the transfer is stopped.
    public func untilResumed() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let goesOn = condition.withLock {
                guard paused && !stopped else { return true }
                waiters.append(continuation)
                return false
            }
            if goesOn { continuation.resume() }
        }
        return !isStopped
    }
}
