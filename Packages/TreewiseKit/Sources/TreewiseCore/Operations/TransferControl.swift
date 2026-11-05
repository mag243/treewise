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
        condition.withLock {
            paused = false
            condition.broadcast()
        }
    }

    /// Stops the transfer, also while it is paused.
    public func stop() {
        condition.withLock {
            stopped = true
            condition.broadcast()
        }
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
    /// providers that do not copy on a thread of their own.
    ///
    /// - Returns: `false` when the transfer is stopped.
    public func untilResumed() async -> Bool {
        while isPaused && !isStopped { await Task.yield() }
        return !isStopped
    }
}
