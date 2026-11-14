import Foundation
import TreewiseCore

/// The bar that offers a template's folders in an empty folder (ADR 0094, ADR 0097): what it
/// offers for a folder, and what closing it and the sheet's checkbox keep in the folders'
/// settings.
@MainActor
public final class TemplateBarModel {
    /// What the bar offers in a folder.
    public struct Offer: Hashable, Sendable {
        /// The folder the bar shows in.
        public let folder: FileItem
        /// Where the folders come from.
        public let source: TemplateBarRule.Source
    }

    private let fileSystem: any FileSystemProviding
    private let settings: any FolderSettingsStoring
    private let templates: any FolderTemplateStoring
    private let addOnMayWork: @MainActor () async -> Bool

    /// A model that reads folders from `fileSystem`, their settings from `settings` and the
    /// templates from `templates`; the bar shows only while `addOnMayWork` says so.
    public init(
        fileSystem: any FileSystemProviding, settings: any FolderSettingsStoring,
        templates: any FolderTemplateStoring, addOnMayWork: @escaping @MainActor () async -> Bool
    ) {
        self.fileSystem = fileSystem
        self.settings = settings
        self.templates = templates
        self.addOnMayWork = addOnMayWork
    }

    /// What the bar offers in `folder`, or nil when it shows none.
    public func offer(in folder: FileItem) async -> Offer? {
        guard folder.kind == .folder, await addOnMayWork(),
            let items = try? await fileSystem.contents(of: folder.id),
            items.allSatisfy(\.isHidden)
        else { return nil }
        var above: FolderSettings?
        if let parent = folder.parentID {
            above = await settings.settings(forFolderAt: parent.rawValue)
        }
        let known = TemplateBarRule.Folder(
            id: folder.id, holdsOnlyHiddenItems: true,
            settings: await settings.settings(forFolderAt: folder.id.rawValue),
            settingsAbove: above,
            yearBeforeHasFolders: await yearBeforeHasFolders(folder.id))
        let source = TemplateBarRule.source(
            for: known, addOnMayWork: true, templates: await templates.templates())
        return source.map { Offer(folder: folder, source: $0) }
    }

    private func yearBeforeHasFolders(_ folder: FileItem.ID) async -> Bool {
        guard let before = YearFolders.folderBefore(folder),
            let items = try? await fileSystem.contents(of: before)
        else { return false }
        return items.contains { FolderTree.keeps($0) }
    }

    /// Don't Show for This Folder: the bar stays closed in `folder`.
    public func close(in folder: FileItem.ID) async {
        await change(folder) { $0.templateBarClosed = true }
    }

    /// Don't Show in the folder above: no folder in `folder` is offered anything.
    public func offerNothing(in folder: FileItem.ID) async {
        await change(folder) { $0.newFolders = .none }
    }

    /// The sheet's checkbox: the empty folders in `folder` are offered `templateID`.
    public func offer(_ templateID: String, in folder: FileItem.ID) async {
        await change(folder) { $0.newFolders = .template(id: templateID) }
    }

    private func change(_ folder: FileItem.ID, _ edit: (inout FolderSettings) -> Void) async {
        var kept =
            await settings.settings(forFolderAt: folder.rawValue)
            ?? FolderSettings(enabledModules: [], templates: [:])
        edit(&kept)
        await settings.save(kept, forFolderAt: folder.rawValue)
    }
}
