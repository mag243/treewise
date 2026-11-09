import Foundation
import Synchronization

/// Coordinates each access to a file with the processes that present it
/// (ADR 0047): iCloud Drive and File Provider apps download a file before it
/// is read, and hear of every change, only through `NSFileCoordinator`. Each
/// call blocks until the presenters let go, so callers run it off Swift's
/// cooperative pool, on the copy queue (ADR 0026).
enum FileCoordination {
    /// Reads `source` in a coordinated access; `body` gets the URL to use.
    static func read<Value>(_ source: URL, _ body: (URL) throws -> Value) throws -> Value {
        var result: Result<Value, any Error>?
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: source, options: [], error: &error
        ) { source in result = Result { try body(source) } }
        return try outcome(result, error)
    }

    /// Reads `source` and writes `target` in one coordinated access; `body`
    /// gets the URLs to use, which may differ from the ones given.
    static func read<Value>(
        _ source: URL, andWrite target: URL, _ body: (URL, URL) throws -> Value
    ) throws -> Value {
        var result: Result<Value, any Error>?
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: source, options: [], writingItemAt: target, options: .forReplacing,
            error: &error
        ) { source, target in result = Result { try body(source, target) } }
        return try outcome(result, error)
    }

    /// Reads `sources` and writes `target` in one coordinated access, for an
    /// operation that takes many items and gives one.
    static func read<Value: Sendable>(
        _ sources: [URL], andWrite target: URL, _ body: @escaping @Sendable () throws -> Value
    ) throws -> Value {
        let intents =
            sources.map { NSFileAccessIntent.readingIntent(with: $0) }
            + [NSFileAccessIntent.writingIntent(with: target, options: .forReplacing)]
        let outcome = Mutex<Result<Value, any Error>?>(nil)
        let finished = DispatchSemaphore(value: 0)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(with: intents, queue: OperationQueue()) { error in
            let result = error.map { .failure($0) } ?? Result { try body() }
            outcome.withLock { $0 = result }
            finished.signal()
        }
        finished.wait()
        guard let result = outcome.withLock({ $0 }) else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    /// Moves `source` to `target` in one coordinated access: `body` moves the
    /// item, and the presenters of `source` learn where it went.
    static func move(_ source: URL, to target: URL, _ body: (URL, URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var result: Result<Void, any Error>?
        var error: NSError?
        coordinator.coordinate(
            writingItemAt: source, options: .forMoving, writingItemAt: target,
            options: .forReplacing, error: &error
        ) { source, target in
            result = Result {
                coordinator.item(at: source, willMoveTo: target)
                try body(source, target)
                coordinator.item(at: source, didMoveTo: target)
            }
        }
        try outcome(result, error)
    }

    /// Writes `url` in a coordinated access, such as creating it.
    static func write<Value>(_ url: URL, _ body: (URL) throws -> Value) throws -> Value {
        try write(url, options: [], body)
    }

    /// Deletes `url`, or moves it to the Trash, in a coordinated access.
    static func delete<Value>(_ url: URL, _ body: (URL) throws -> Value) throws -> Value {
        try write(url, options: .forDeleting, body)
    }

    private static func write<Value>(
        _ url: URL, options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Value
    ) throws -> Value {
        var result: Result<Value, any Error>?
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: url, options: options, error: &error
        ) { url in result = Result { try body(url) } }
        return try outcome(result, error)
    }

    /// What a coordinated access came to: the coordinator's own error when it
    /// could not start, else what the accessor's body returned or threw.
    @discardableResult
    private static func outcome<Value>(_ result: Result<Value, any Error>?, _ error: NSError?)
        throws -> Value
    {
        if let error { throw error }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
}
