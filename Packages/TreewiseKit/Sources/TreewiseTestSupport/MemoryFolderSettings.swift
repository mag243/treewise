import Synchronization
import TreewiseCore

/// Folder settings in memory, for tests of what uses them.
public final class MemoryFolderSettings: FolderSettingsStoring {
    private let saved = Mutex<[String: FolderSettings]>([:])

    /// Creates a store without settings.
    public init() {}

    /// The settings of the folder at a path, or nil when it has none.
    public func settings(forFolderAt path: String) async -> FolderSettings? {
        saved.withLock { $0[path] }
    }

    /// Saves the settings of the folder at a path.
    public func save(_ settings: FolderSettings, forFolderAt path: String) async {
        saved.withLock { $0[path] = settings }
    }
}
