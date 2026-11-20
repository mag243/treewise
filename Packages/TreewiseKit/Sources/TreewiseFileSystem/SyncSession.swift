import Foundation
import TreewiseCore

/// The sync of one device at work (ADR 0144): the folder settings and the templates tell it
/// what the user changes, and what other devices changed is taken over into them. The saved
/// patterns live in the app's settings, so their changes are handed back to the app.
public actor SyncSession {
    private let sync: SettingsSync
    private let folders: FolderSettingsStore
    private let templates: FolderTemplateStore
    private var isRunning = false

    /// A session of `sync` over `folders` and `templates`.
    public init(sync: SettingsSync, folders: FolderSettingsStore, templates: FolderTemplateStore) {
        self.sync = sync
        self.folders = folders
        self.templates = templates
    }

    /// Starts syncing through the drives at `drives`: reads what the files hold, records the
    /// settings this device had from before for keys no file knows, and from then on records
    /// every change. `patterns` are the saved patterns as the app keeps them. Returns the
    /// saved patterns of another device for the app to take over, if any.
    public func start(drives: [URL], patterns: SavedPatterns?) async -> [SettingsSync.Change] {
        await sync.setDrives(drives)
        let first = await refresh()
        let known = await templates.templates()
        var shared: [SyncKey: SyncValue] = [:]
        // The examples a new installation starts with are no one's choice: seeding them
        // could set them over another device's own list at the same seed time.
        if let patterns, !patterns.isExamples() {
            shared[.savedPatterns] = .savedPatterns(patterns)
        }
        for template in known { shared[.template(template.id)] = .template(template) }
        await sync.seed(folders: await folders.allSettings(), shared: shared)
        let sync = sync
        await folders.tellChanges { await sync.handle($0) }
        await templates.tellChanges { await sync.handle($0) }
        isRunning = true
        return first
    }

    /// Stops syncing: nothing is read or written in the drives any more.
    public func stop() async {
        await folders.stopTellingChanges()
        await templates.stopTellingChanges()
        await sync.setDrives([])
        isRunning = false
    }

    /// Reads the drives' files again, as when the provider brought another device's change:
    /// takes over the folder settings and templates, and returns the changes to the saved
    /// patterns for the app.
    @discardableResult
    public func refresh() async -> [SettingsSync.Change] {
        await folders.changesTold()
        await templates.changesTold()
        var forTheApp: [SettingsSync.Change] = []
        for change in await sync.refresh() {
            switch change {
            case .folder(let path, let settings):
                await folders.takeOver(settings, forFolderAt: path)
            case .template(let id, let template):
                await templates.takeOver(template, id: id)
            case .savedPatterns:
                forTheApp.append(change)
            }
        }
        return forTheApp
    }

    /// The user changed the saved patterns: one of them, their order or the default.
    public func patternsChanged(_ patterns: SavedPatterns) async {
        guard isRunning else { return }
        await sync.changed(.savedPatterns, to: .savedPatterns(patterns))
    }

    /// Returns once every change the stores told so far is recorded and written.
    public func settle() async {
        await folders.changesTold()
        await templates.changesTold()
    }
}
