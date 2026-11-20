import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import TreewiseUI

/// What every window shares of folder structure templates (ADR 0091, ADR 0095, ADR 0099):
/// the saved templates, and the add-on with whether it may work now. Templates are Treewise's
/// own and are in every build; the add-on adds recognizing fields on saving and the bar.
/// Menus are built at once, so they read what `refresh` found last.
@MainActor
enum FolderTemplatesService {
    /// The saved templates.
    static let store = FolderTemplateStore(directory: LaunchOptions.folderTemplatesDirectory)
    /// The templates as menus, sheets and Settings show them.
    static let templates = FolderTemplatesModel(store: store)

    /// What changes while Treewise runs: the copied structure and the add-on's state.
    static let state = FolderTemplatesState()

    /// The structure Copy Folder Structure copied (ADR 0099).
    static var copiedStructure: FolderTree? {
        get { state.copiedStructure }
        set { state.copiedStructure = newValue }
    }

    /// The name of each add-on the build carries, by its id (ADR 0101).
    static var addOnNames: [String: String] { state.addOnNames }

    /// Whether the build carries the add-on and it may work now.
    static var addOnMayWork: Bool { state.addOnMayWork }

    /// Finds the add-on and its licence state, and reads the templates.
    static func refresh(licences: LicenceKeeper?) async {
        let host = AppServices.moduleHost
        let modules = (try? await host.availableModules()) ?? []
        let names = Dictionary(
            modules.map { ($0.id, NameReviewText.name(of: $0)) },
            uniquingKeysWith: { first, _ in first })
        let found = modules.first(where: \.makesFolderStructures)
        var mayWork = false
        if let found {
            let licence = try? await host.licenceState(
                moduleID: found.id, licence: licences?.context() ?? .none)
            mayWork = licence?.mayWork ?? true
        }
        state.found(addOnID: found?.id, mayWork: mayWork, addOnNames: names)
        await templates.load()
    }

    /// The add-on to ask, while it may work.
    static func addOn(licences: LicenceKeeper?) -> FolderStructureAddOn? {
        guard let addOnID = state.addOnID, state.mayWork else { return nil }
        return FolderStructureAddOn(
            host: AppServices.moduleHost, moduleID: addOnID,
            licence: { licences?.context() ?? .none })
    }

    /// The tree of `folder`, each folder with its name settings while the add-on may work
    /// (ADR 0101), for saving it, copying it or offering it in the bar.
    static func tree(of folder: FileItem, in fileSystem: any FileSystemProviding) async throws
        -> FolderTree
    {
        guard addOnMayWork else { return try await fileSystem.folderTree(of: folder) }
        let store = AppServices.folderSettings
        return try await fileSystem.folderTree(of: folder) { await store.names(of: $0) }
    }

    /// Gives the folders made from `tree` the name settings it keeps, while the add-on may
    /// work (ADR 0101).
    static func giveNames(of tree: FolderTree, to made: [[String]: FileItem.ID]) async {
        guard addOnMayWork else { return }
        await AppServices.folderSettings.give(
            namesOf: tree, to: made, catalog: Set(addOnNames.keys))
    }

    /// Add to Template: adds the folders of `offer` that `template` lacks to it, with Undo
    /// (ADR 0102).
    static func addMissing(
        of offer: TemplateBarModel.MissingOffer, to template: FolderTemplate,
        undoManager: UndoManager?
    ) async {
        await templates.addMissing(
            offer.missing, from: offer.recognized, year: offer.year, to: template.id,
            undoManager: undoManager)
    }

    /// The bar's state, for the folders of `browser`'s file system.
    static func bar(for browser: BrowserState) -> TemplateBarModel {
        let fileSystem = browser.fileSystem
        let licences = browser.licences
        let bar = TemplateBarModel(
            fileSystem: fileSystem, settings: AppServices.folderSettings, templates: store,
            addOnMayWork: { addOnMayWork },
            yearBefore: { await recognized($0, in: fileSystem, licences: licences) },
            offersMissingFolders: { AppServices.settings.offersMissingFolders })
        bar.isSpelledCorrectly = isSpelledCorrectly
        return bar
    }

    /// Whether `name` is spelled correctly in one of the languages the user chose for the
    /// spelling checker, as macOS checks it (ADR 0139).
    static func isSpelledCorrectly(_ name: String) -> Bool {
        let checker = NSSpellChecker.shared
        let languages = checker.userPreferredLanguages
        return languages.contains { language in
            checker.checkSpelling(
                of: name, startingAt: 0, language: language, wrap: false,
                inSpellDocumentWithTag: 0, wordCount: nil
            ).location == NSNotFound
        }
    }

    /// The folder at `id` read as a template, with the year as `{year}` and what else the
    /// add-on recognizes (ADR 0094, ADR 0102); nil while the add-on may not work.
    static func recognized(
        _ id: FileItem.ID, in fileSystem: any FileSystemProviding, licences: LicenceKeeper?
    ) async -> FolderTree? {
        guard let addOn = addOn(licences: licences),
            let folder = try? await fileSystem.item(at: id),
            let tree = try? await tree(of: folder, in: fileSystem)
        else { return nil }
        return try? await addOn.host.template(
            moduleID: addOn.moduleID, from: tree, yearAbove: YearFolders.year(of: id),
            licence: licences?.context() ?? .none)
    }
}
