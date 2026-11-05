import AppKit
import TreewiseCore
import TreewiseFileSystem
import UniformTypeIdentifiers
import os

/// Drops of files another app promises to write, such as an attachment from
/// Mail (ADR 0020). The files arrive in a hidden inbox in the target folder,
/// are copied out of it like any other copy, and the inbox is then removed.
@MainActor
enum PromisedDrop {
    /// Used from the queue the promised files arrive on, too.
    private nonisolated static let logger = Logger(
        subsystem: "me.m-domain.treewise", category: "drop")

    /// The pasteboard types of a file promise, for AppKit drop targets.
    static let pasteboardTypes = NSFilePromiseReceiver.readableDraggedTypes.map {
        NSPasteboard.PasteboardType($0)
    }

    /// The same types for SwiftUI drop targets.
    static let contentTypes = NSFilePromiseReceiver.readableDraggedTypes.compactMap {
        UTType($0)
    }

    /// Whether a drag pasteboard carries promised files and no file URLs:
    /// an app that offers both is dragged as items.
    static func isPromised(_ pasteboard: NSPasteboard) -> Bool {
        let available = pasteboard.types ?? []
        return !available.contains(.fileURL) && available.contains { pasteboardTypes.contains($0) }
    }

    /// Asks the source app to write its files into an inbox in `target`, then
    /// drops what arrived as a copy (⌥) and removes the inbox. Returns `false`
    /// when there is nothing to receive or no inbox can be made.
    static func receive(
        _ pasteboard: NSPasteboard, into target: FileItem, with drop: @escaping DropAction
    ) -> Bool {
        guard
            let receivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self])
                as? [NSFilePromiseReceiver], !receivers.isEmpty
        else { return false }
        let inbox: URL
        do {
            inbox = try PromiseInbox.make(in: URL(fileURLWithPath: target.id.rawValue))
        } catch {
            logger.error("No inbox in \(target.id.rawValue, privacy: .public): \(error)")
            return false
        }
        // AppKit expects the files to be asked for while the drop is handled.
        let arrivals = request(receivers, into: inbox)
        Task {
            var items: [FileItem] = []
            for await url in arrivals {
                if let item = DropRouting.item(at: FileItem.ID(url.standardizedFileURL.path)) {
                    items.append(item)
                }
            }
            if !items.isEmpty { await drop(items, target, .option) }
            do {
                try PromiseInbox.discard(inbox)
            } catch {
                logger.error("Inbox \(inbox.path, privacy: .public) stays: \(error)")
            }
        }
        return true
    }

    /// The files as they arrive in the inbox; the stream ends when every
    /// promised file has arrived or failed.
    private static func request(_ receivers: [NSFilePromiseReceiver], into inbox: URL)
        -> AsyncStream<URL>
    {
        let expected = receivers.map(\.fileTypes.count).reduce(0, +)
        let (stream, continuation) = AsyncStream.makeStream(of: URL.self)
        guard expected > 0 else {
            continuation.finish()
            return stream
        }
        let reader = arrivals(expected: expected, into: continuation)
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        for receiver in receivers {
            receiver.receivePromisedFiles(
                atDestination: inbox, options: [:], operationQueue: queue, reader: reader)
        }
        return stream
    }

    /// The reader for every promised file: it passes each arrived file on and
    /// ends the stream after the last one, arrived or failed.
    private nonisolated static func arrivals(
        expected: Int, into continuation: AsyncStream<URL>.Continuation
    ) -> @Sendable (URL, (any Error)?) -> Void {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        return { url, error in
            if let error {
                logger.error("A promised file did not arrive: \(error)")
            } else {
                continuation.yield(url)
            }
            let arrived = counter.withLock { count in
                count += 1
                return count
            }
            if arrived == expected { continuation.finish() }
        }
    }
}
