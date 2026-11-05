#if os(macOS)
    import Foundation
    import Synchronization

    /// A reply being waited for. A reply, an error, a timeout and a cancellation can
    /// all race: the first one counts, and resuming twice would be a crash.
    final class PendingReply: Sendable {
        private enum State {
            case idle
            case waiting(CheckedContinuation<Data?, any Error>)
            case finished(Result<Data?, any Error>)
        }

        private let state = Mutex(State.idle)

        /// Waits for the outcome, which may have come already: cancelling a task runs
        /// its handler before the task gets here.
        func wait() async throws -> Data? {
            try await withCheckedThrowingContinuation { waiting in
                let early: Result<Data?, any Error>? = state.withLock { state in
                    if case .finished(let outcome) = state { return outcome }
                    state = .waiting(waiting)
                    return nil
                }
                if let early { waiting.resume(with: early) }
            }
        }

        /// Ends the wait, unless it has ended already.
        func finish(_ outcome: Result<Data?, any Error>) {
            let waiting: CheckedContinuation<Data?, any Error>? = state.withLock { state in
                switch state {
                case .finished:
                    return nil
                case .idle:
                    state = .finished(outcome)
                    return nil
                case .waiting(let waiting):
                    state = .finished(outcome)
                    return waiting
                }
            }
            waiting?.resume(with: outcome)
        }
    }
#endif
