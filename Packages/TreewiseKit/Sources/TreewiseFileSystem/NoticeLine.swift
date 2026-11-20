import Foundation

/// Tells notices to a handler one at a time and in order, on a task of its own, so a store
/// can tell a change without waiting for the handler (ADR 0144).
final class NoticeLine<Notice: Sendable>: Sendable {
    private enum Item: Sendable {
        case notice(Notice)
        case mark(CheckedContinuation<Void, Never>)
    }

    private let continuation: AsyncStream<Item>.Continuation

    /// A line that tells `handle` each notice.
    init(handle: @escaping @Sendable (Notice) async -> Void) {
        let (stream, continuation) = AsyncStream.makeStream(of: Item.self)
        self.continuation = continuation
        Task {
            for await item in stream {
                switch item {
                case .notice(let notice): await handle(notice)
                case .mark(let waiting): waiting.resume()
                }
            }
        }
    }

    /// Tells `notice` after those told before it.
    func tell(_ notice: Notice) {
        continuation.yield(.notice(notice))
    }

    /// Returns once every notice told before has been handled.
    func told() async {
        await withCheckedContinuation { waiting in
            if case .terminated = continuation.yield(.mark(waiting)) { waiting.resume() }
        }
    }

    /// Ends the line; notices told after are dropped.
    func finish() {
        continuation.finish()
    }
}
