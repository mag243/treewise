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

    let fileSystem: any FileSystemProviding
    let settings: any FolderSettingsStoring
    let templates: any FolderTemplateStoring
    let addOnMayWork: @MainActor () async -> Bool
    /// The folder at an id read as a template, as the add-on recognizes it (ADR 0102).
    let yearBefore: @MainActor (FileItem.ID) async -> FolderTree?
    /// Whether the bar offers missing folders, as Settings says (ADR 0102).
    let offersMissingFolders: @MainActor () -> Bool
    /// Whether a name is spelled correctly in the user's languages, as the system's spelling
    /// checker says; two names that both are never count as one folder by likeness alone
    /// (ADR 0139). Without a checker, no name is.
    public var isSpelledCorrectly: @MainActor (String) -> Bool = { _ in false }

    /// A model that reads folders from `fileSystem`, their settings from `settings` and the
    /// templates from `templates`; the bar shows only while `addOnMayWork` says so. Missing
    /// folders come from `yearBefore`, and the bar offers them while `offersMissingFolders`
    /// says so (ADR 0102).
    public init(
        fileSystem: any FileSystemProviding, settings: any FolderSettingsStoring,
        templates: any FolderTemplateStoring, addOnMayWork: @escaping @MainActor () async -> Bool,
        yearBefore: @escaping @MainActor (FileItem.ID) async -> FolderTree? = { _ in nil },
        offersMissingFolders: @escaping @MainActor () -> Bool = { true }
    ) {
        self.fileSystem = fileSystem
        self.settings = settings
        self.templates = templates
        self.addOnMayWork = addOnMayWork
        self.yearBefore = yearBefore
        self.offersMissingFolders = offersMissingFolders
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

    func change(_ folder: FileItem.ID, _ edit: (inout FolderSettings) -> Void) async {
        var kept =
            await settings.settings(forFolderAt: folder.rawValue)
            ?? FolderSettings(enabledModules: [], templates: [:])
        edit(&kept)
        await settings.save(kept, forFolderAt: folder.rawValue)
    }
}
