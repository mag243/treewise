import AppKit
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import TreewiseUI

/// What every window shares of folder structure templates (ADR 0091, ADR 0095): the saved
/// templates, the add-on that makes them, and whether it may work now. Menus are built at
/// once, so they read what `refresh` found last; nothing of templates shows in a build
/// without the add-on, or while it may not work.
@MainActor
enum FolderTemplatesService {
    /// The saved templates.
    static let store = FolderTemplateStore(directory: LaunchOptions.folderTemplatesDirectory)
    /// The templates as menus, sheets and Settings show them.
    static let templates = FolderTemplatesModel(store: store)

    /// The id of the add-on that makes folder structures, when the build carries one.
    private(set) static var addOnID: String?
    /// Whether that add-on may work, with a licence or in its trial (ADR 0088).
    private(set) static var mayWork = false

    /// Whether menus offer templates now.
    static var isOffered: Bool { addOnID != nil && mayWork }

    /// Finds the add-on and its licence state, and reads the templates.
    static func refresh(licences: LicenceKeeper?) async {
        let host = NameReviewWindow.host
        let found = ((try? await host.availableModules()) ?? []).first(
            where: \.makesFolderStructures)
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

    /// What the sheet asks the add-on with.
    static func asking(licences: LicenceKeeper?) -> FolderTemplateSheetModel.Asking? {
        guard let addOnID else { return nil }
        return FolderTemplateSheetModel.Asking(
            host: NameReviewWindow.host, moduleID: addOnID,
            licence: { licences?.context() ?? .none })
    }

    /// The bar's state, for the folders of `browser`'s file system.
    static func bar(for fileSystem: any FileSystemProviding) -> TemplateBarModel {
        TemplateBarModel(
            fileSystem: fileSystem, settings: NameReviewWindow.store, templates: store,
            addOnMayWork: { isOffered })
    }
}
