import AppKit
import TreewiseCore
import UniformTypeIdentifiers

/// An entry of an archive on a drag (ADR 0076). Nothing is extracted when the
/// drag starts: another app gets a file promise, kept when it drops. Treewise
/// reads the entry's identifier and copies it as any other drop.
final class ArchiveEntryDrag: NSFilePromiseProvider, NSFilePromiseProviderDelegate {
    /// The private type that holds an entry's identifier.
    static let entryType = NSPasteboard.PasteboardType("me.m-domain.treewise.archive-entry")

    private let entry: FileItem
    private let write: @Sendable (URL) async throws -> Void

    /// Creates a drag of `entry`; `write` copies it to the file asked for.
    init(entry: FileItem, write: @escaping @Sendable (URL) async throws -> Void) {
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

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [Self.entryType] + super.writableTypes(for: pasteboard)
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        type == Self.entryType ? entry.id.rawValue : super.pasteboardPropertyList(forType: type)
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String
    ) -> String {
        entry.name
    }

    func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let write = write
        // AppKit calls it once, on any thread, so it may cross to the task.
        nonisolated(unsafe) let done = completionHandler
        Task {
            do {
                try await write(url)
                done(nil)
            } catch {
                done(error)
            }
        }
    }
}
