import AppKit
import TreewiseCore
import UniformTypeIdentifiers

/// An entry of an archive on a drag (ADR 0076). Nothing is extracted when the
/// drag starts: another app gets a file promise, kept when it drops. Treewise
/// reads the entry's identifier and copies it as any other drop.
final class ArchiveEntryDrag: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
    /// The private type that holds an entry's identifier.
    static let entryType = NSPasteboard.PasteboardType("me.m-domain.treewise.archive-entry")

    private static let writing = OperationQueue()

    private let entry: FileItem
    private let write: @Sendable (URL) async -> Void

    /// Creates a drag of `entry`; `write` copies it to the file asked for.
    init(entry: FileItem, write: @escaping @Sendable (URL) async -> Void) {
        self.entry = entry
        self.write = write
        super.init()
        let fileExtension = (entry.name as NSString).pathExtension
        let type = entry.isContainer ? UTType.folder : UTType(filenameExtension: fileExtension)
        fileType = (type ?? .data).identifier
        delegate = self
    }

    /// The identifiers of the entries on a drag pasteboard.
    static func identifiers(on pasteboard: NSPasteboard) -> [FileItem.ID] {
        (pasteboard.pasteboardItems ?? []).compactMap { $0.string(forType: entryType) }
            .map { FileItem.ID($0) }
    }

    /// Takes the promises of entries off the drag pasteboard. Call when
    /// quitting: a promise nobody kept, after a drop within Treewise or a drag
    /// that landed nowhere, holds up quitting for a minute.
    static func releasePromises() {
        let pasteboard = NSPasteboard(name: .drag)
        if !identifiers(on: pasteboard).isEmpty { pasteboard.clearContents() }
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        // The promise's own types come first: they are what another app reads.
        super.writableTypes(for: pasteboard) + [Self.entryType]
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        type == Self.entryType ? entry.id.rawValue : super.pasteboardPropertyList(forType: type)
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String
    ) -> String {
        entry.name
    }

    /// Off the main queue, which the drag keeps busy until the file is there.
    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        Self.writing
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let write = write
        // AppKit calls it once, on any thread, so it may cross to the task.
        nonisolated(unsafe) let done = completionHandler
        Task {
            await write(url)
            done(nil)
        }
    }
}
