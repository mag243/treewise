import Foundation
import TreewiseCore

/// What the user changed in a folder's settings, told to a sync in order (ADR 0144).
public enum FolderSettingsNotice: Hashable, Sendable {
    /// The settings of the folder at `path` went from `before` to `after`, nil for none.
    case changed(path: String, before: FolderSettings?, after: FolderSettings?)
    /// Treewise moved the folder at `old` to `new`.
    case moved(from: String, to: String)
}

extension FolderSettingsStore {
    /// Tells `handle` of every change the user makes from now on, one at a time and in
    /// order; a change taken over from another device, or a clean-up, is not told.
    public func tellChanges(to handle: @escaping @Sendable (FolderSettingsNotice) async -> Void) {
        notices?.finish()
        notices = NoticeLine(handle: handle)
    }

    /// Returns once every change told so far has been handled.
    public func changesTold() async {
        await notices?.told()
    }

    /// Stops telling changes.
    public func stopTellingChanges() {
        notices?.finish()
        notices = nil
    }

    /// Takes over another device's change to the folder at `path`, without telling it:
    /// its settings, or none when nil.
    public func takeOver(_ settings: FolderSettings?, forFolderAt path: String) {
        let telling = notices
        notices = nil
        defer { notices = telling }
        if let settings {
            save(settings, forFolderAt: path)
        } else if let id = settledID(forFolderAt: path) {
            records?[id] = nil
            persist()
        }
    }

    /// The settings of every folder, by its path, for a sync to start from.
    public func allSettings() -> [String: FolderSettings] {
        loadIfNeeded()
        return Dictionary(
            (records ?? [:]).values.map { ($0.path, $0.settings) },
            uniquingKeysWith: { first, _ in first })
    }
}
