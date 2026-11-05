import AppKit
import TreewiseCore

/// Opens files the browser hands back, in their default application.
@MainActor
enum FileOpener {
    /// The folder a symlink points to, when it points to a folder.
    static func linkedFolder(of item: FileItem) -> FileItem.ID? {
        let url = URL(fileURLWithPath: item.id.rawValue)
        let target = url.resolvingSymlinksInPath()
        guard target != url,
            (try? target.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else { return nil }
        return FileItem.ID(target.path)
    }

    /// Opens a file in its default application.
    static func open(_ item: FileItem) {
        NSWorkspace.shared.open(URL(fileURLWithPath: item.id.rawValue))
    }
}
