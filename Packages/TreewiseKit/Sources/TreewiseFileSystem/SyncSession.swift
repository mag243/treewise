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
    /// This device's changes another device's replaced without seeing them (ADR 0144).
    public private(set) var conflicts: [SyncBook.Conflict] = []

    /// A session of `sync` over `folders` and `templates`.
    public init(sync: SettingsSync, folders: FolderSettingsStore, templates: FolderTemplateStore) {
        self.sync = sync
        self.folders = folders
        self.templates = templates
    }

    /// Starts syncing through the drives at `drives`: gives the templates' folders their
    /// ids, reads what the files hold, records the settings this device had from before for
    /// elements no file knows, and from then on records every change. `patterns` are the
    /// saved patterns as the app keeps them. Returns another device's saved patterns for the
    /// app to take over, if any.
    public func start(drives: [URL], patterns: SavedPatterns?) async -> [SettingsSync.Change] {
        await sync.setDrives(drives)
        for template in await templates.templates() {
            let withIDs = template.withFolderIDs()
            if withIDs != template { await templates.takeOver(withIDs, id: withIDs.id) }
        }
        let first = await refresh()
        let untouched = patterns.map { $0.isExamples() } ?? true
        await sync.seed(
            folders: await folders.allSettings(), patterns: untouched ? nil : patterns,
            templates: await templates.templates())
        let sync = sync
        let templates = templates
        await folders.tellChanges { await sync.handle($0) }
        await templates.tellChanges { notice in
            await Self.handle(notice, sync: sync, templates: templates)
        }
        isRunning = true
        return first
    }

    /// Syncs through the drives at `drives` from now on, as when a location was added or
    /// removed: reads them, and records the settings of folders in a new drive that no file
    /// knows. Returns another device's saved patterns for the app, if any.
    public func changeDrives(_ drives: [URL]) async -> [SettingsSync.Change] {
        guard isRunning else { return [] }
        await sync.setDrives(drives)
        let changes = await refresh()
        await sync.seed(folders: await folders.allSettings(), patterns: nil, templates: [])
        return changes
    }

    /// Records a change to the templates, giving a folder added an id first.
    private static func handle(
        _ notice: FolderTemplateNotice, sync: SettingsSync, templates: FolderTemplateStore
    ) async {
        switch notice {
        case .saved(let template, let before):
            let withIDs = template.withFolderIDs()
            if withIDs != template { await templates.takeOver(withIDs, id: withIDs.id) }
            await sync.templateChanged(id: template.id, from: before, to: withIDs)
        case .deleted(let id, let before):
            await sync.templateChanged(id: id, from: before, to: nil)
        }
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
        await settle()
        let refreshed = await sync.refresh()
        conflicts += refreshed.lost
        return await apply(refreshed.changes)
    }

    /// Takes over the folder settings and templates in `changes`, and returns the rest for
    /// the app.
    private func apply(_ changes: [SettingsSync.Change]) async -> [SettingsSync.Change] {
        var forTheApp: [SettingsSync.Change] = []
        for change in changes {
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

    /// Restore in the safety net: `conflict`'s value of this device holds again, here and on
    /// the other devices. Returns the saved patterns for the app when it changed them.
    public func restore(_ conflict: SyncBook.Conflict) async -> [SettingsSync.Change] {
        conflicts.removeAll { $0 == conflict }
        return await apply(await sync.restore(conflict.mine))
    }

    /// Forgets the conflicts, once the app keeps them.
    public func clearConflicts() {
        conflicts = []
    }

    /// Why this device does not sync in a drive, by the drive's path (ADR 0144).
    public func driveProblems() async -> [String: SyncFolder.Problem] {
        await sync.driveProblems
    }

    /// The name of the device with `id`, as its file gives it.
    public func deviceName(_ id: String) async -> String? {
        await sync.deviceNames[id]
    }

    /// The user changed the saved patterns from `before` to `after`.
    public func patternsChanged(from before: SavedPatterns, to after: SavedPatterns) async {
        guard isRunning else { return }
        await sync.patternsChanged(from: before, to: after)
    }

    /// Returns once every change the stores told so far is recorded and written.
    public func settle() async {
        await folders.changesTold()
        await templates.changesTold()
    }
}
