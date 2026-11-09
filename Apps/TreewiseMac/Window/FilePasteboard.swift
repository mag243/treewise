import AppKit
import TreewiseCore
import TreewiseUI

/// The general pasteboard as Treewise uses it for files (PLAN.md §4.3): cut and
/// copy put the items' file URLs on it, so pasting in Finder works; files put
/// there by another app are pasted as copies.
@MainActor
enum FilePasteboard {
    /// The pasteboard's change count right after Treewise wrote to it.
    private static var ownChangeCount: Int?

    /// Puts file URLs of items on the pasteboard.
    static func write(_ items: [FileItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.compactMap { $0.id.diskURL as NSURL? })
        ownChangeCount = pasteboard.changeCount
    }

    /// Whether another app has put something on the pasteboard since Treewise did.
    static var changedElsewhere: Bool {
        NSPasteboard.general.changeCount != ownChangeCount
    }

    /// Whether the pasteboard holds file URLs. Asks only for the types, not the
    /// contents, which macOS lets an app do without asking the user; reading
    /// the contents (`fileURLs`) is left to an actual paste.
    static var hasFileURLs: Bool {
        NSPasteboard.general.types?.contains(.fileURL) ?? false
    }

    /// The file URLs on a pasteboard: the general one only when the user
    /// pastes, the drag pasteboard while a drag is on its way.
    static func fileURLs(on pasteboard: NSPasteboard = .general) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }
}
