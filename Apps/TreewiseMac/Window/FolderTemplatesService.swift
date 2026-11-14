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

    /// The structure Copy Folder Structure copied, for Paste Folder Structure… in any window
    /// (ADR 0099); nil until a folder's structure is copied.
    static var copiedStructure: FolderTree?

    /// The id of the add-on that makes folder structures, when the build carries one.
    private static var addOnID: String?
    /// Whether that add-on may work, with a licence or in its trial (ADR 0088).
    private static var mayWork = false

    /// The name of each add-on the build carries, by its id, for the name settings a
    /// template keeps (ADR 0101).
    private(set) static var addOnNames: [String: String] = [:]

    /// Whether the build carries the add-on and it may work now.
    static var addOnMayWork: Bool { addOnID != nil && mayWork }

    /// Finds the add-on and its licence state, and reads the templates.
    static func refresh(licences: LicenceKeeper?) async {
        let host = NameReviewWindow.host
        let modules = (try? await host.availableModules()) ?? []
        addOnNames = Dictionary(
            modules.map { ($0.id, NameReviewText.name(of: $0)) },
            uniquingKeysWith: { first, _ in first })
        let found = modules.first(where: \.makesFolderStructures)
        addOnID = found?.id
        if let found {
            let state = try? await host.licenceState(
                moduleID: found.id, licence: licences?.context() ?? .none)
            mayWork = state?.mayWork ?? true
        } else {
            mayWork = false
        }
        await templates.load()
    }

    /// The add-on to ask, while it may work.
    static func addOn(licences: LicenceKeeper?) -> FolderStructureAddOn? {
        guard let addOnID, mayWork else { return nil }
        return FolderStructureAddOn(
            host: NameReviewWindow.host, moduleID: addOnID,
            licence: { licences?.context() ?? .none })
    }

    /// The tree of `folder`, each folder with its name settings while the add-on may work
    /// (ADR 0101), for saving it, copying it or offering it in the bar.
    static func tree(of folder: FileItem, in fileSystem: any FileSystemProviding) async throws
        -> FolderTree
    {
        guard addOnMayWork else { return try await fileSystem.folderTree(of: folder) }
        let store = NameReviewWindow.store
        return try await fileSystem.folderTree(of: folder) { await store.names(of: $0) }
    }

    /// Gives the folders made from `tree` the name settings it keeps, while the add-on may
    /// work (ADR 0101).
    static func giveNames(of tree: FolderTree, to made: [[String]: FileItem.ID]) async {
        guard addOnMayWork else { return }
        await NameReviewWindow.store.give(
            namesOf: tree, to: made, catalog: Set(addOnNames.keys))
    }

    /// The bar's state, for the folders of `browser`'s file system.
    static func bar(for fileSystem: any FileSystemProviding) -> TemplateBarModel {
        TemplateBarModel(
            fileSystem: fileSystem, settings: NameReviewWindow.store, templates: store,
            addOnMayWork: { addOnMayWork })
    }
}
