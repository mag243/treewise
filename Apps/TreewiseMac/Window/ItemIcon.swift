import AppKit
import TreewiseCore
import TreewiseUI
import UniformTypeIdentifiers

/// The icon of an item, also for one inside an archive, where no file exists
/// to ask the system about (ADR 0076).
@MainActor
enum ItemIcon {
    /// The system's icon of an item on disk; inside an archive the archive's
    /// at its top level, and a folder below it.
    static func image(for id: FileItem.ID) -> NSImage {
        if let path = id.diskPath { return NSWorkspace.shared.icon(forFile: path) }
        if ArchivePath(id)?.isTopLevel == true {
            return NSWorkspace.shared.icon(forFile: id.urlShownInFinder.path)
        }
        return NSWorkspace.shared.icon(for: .folder)
    }

    /// The icon of a row or tile: inside an archive a file gets the icon of its type.
    static func image(for item: FileItem) -> NSImage {
        guard item.id.isInsideArchive, item.kind == .file else { return image(for: item.id) }
        let fileExtension = (item.name as NSString).pathExtension
        return NSWorkspace.shared.icon(for: UTType(filenameExtension: fileExtension) ?? .data)
    }
}
