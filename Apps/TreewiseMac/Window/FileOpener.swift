import AppKit
import TreewiseCore
import TreewiseUI

/// Opens files the browser hands back, in their default application.
@MainActor
enum FileOpener {
    /// The folder a symlink points to, when it points to a folder.
    static func linkedFolder(of item: FileItem) -> FileItem.ID? {
        guard let url = item.id.diskURL else { return nil }
        let target = url.resolvingSymlinksInPath()
        guard target != url,
            (try? target.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        else { return nil }
        return FileItem.ID(target.path)
    }

    /// Opens a file in its default application.
    static func open(_ item: FileItem) {
        guard let url = item.id.diskURL else { return }
        openInDefaultApp(url)
    }

    /// Opens a file in its default application, or, under a UI test, notes it in the test's
    /// log instead, so no other app starts on the Mac the tests run on.
    static func openInDefaultApp(_ url: URL) {
        guard let log = LaunchOptions.openedLog else {
            NSWorkspace.shared.open(url)
            return
        }
        let line = Data((url.path + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: log) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            try? line.write(to: log)
        }
    }
}
