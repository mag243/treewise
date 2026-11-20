import SwiftUI
import TreewiseCore
import TreewiseUI

/// What a folder's Folder Structure ▸ asks for (ADR 0091, ADR 0099): to save the folder's
/// structure as a template, to make a template's folders in it, to copy its structure, or to
/// paste the structure copied; and Rename in All Years…, which corrects the templates along
/// (ADR 0139).
enum FolderStructureRequest: Identifiable {
    case save(FileItem.ID)
    case make(FolderTemplate, in: FileItem.ID)
    case copy(FileItem.ID)
    case paste(FolderTree, in: FileItem.ID)
    case renameInAllYears(FileItem)

    var id: String {
        switch self {
        case .save(let folder): "save " + folder.rawValue
        case .make(let template, let folder): "make \(template.id) " + folder.rawValue
        case .copy(let folder): "copy " + folder.rawValue
        case .paste(let tree, let folder): "paste \(tree.name) " + folder.rawValue
        case .renameInAllYears(let folder): "rename " + folder.id.rawValue
        }
    }
}

/// The folder view's answer to Folder Structure ▸: Copy Structure reads the folder's tree at
/// once, and says why when it cannot; the others open a sheet.
@MainActor
@Observable
final class FolderStructureAsked {
    /// The sheet shown, if any.
    var shown: FolderStructureRequest?
    /// Why the structure could not be copied, while that is said.
    var problem: String?

    func ask(_ request: FolderStructureRequest, browser: BrowserState) {
        guard case .copy(let folder) = request else {
            shown = request
            return
        }
        Task { await copy(folder, in: browser.fileSystem) }
    }

    private func copy(_ folder: FileItem.ID, in fileSystem: any FileSystemProviding) async {
        do {
            let item = try await fileSystem.item(at: folder)
            NameServices.templateState.copiedStructure = try await fileSystem.folderTree(
                of: item)
        } catch let found as FolderTree.Problem {
            problem = TemplateProblemText.text(for: found)
        } catch {
            problem = String(localized: "The folder’s structure could not be read.")
        }
    }
}

/// The sheets and the alert of Folder Structure ▸, on the folder view.
struct FolderStructureSheets: ViewModifier {
    @Bindable var asked: FolderStructureAsked
    let browser: BrowserState
    let undoManager: UndoManager

    func body(content: Content) -> some View {
        content
            .sheet(item: $asked.shown) { request in
                switch request {
                case .save(let folder):
                    SaveTemplateSheet(folder: folder, browser: browser)
                case .make(let template, let folder):
                    NewFoldersFromTemplateSheet(
                        title: String(localized: "New Folders from “\(template.name)”"),
                        tree: template.root, template: template, folder: folder,
                        browser: browser, undoManager: undoManager)
                case .paste(let tree, let folder):
                    NewFoldersFromTemplateSheet(
                        title: String(localized: "Paste the Structure of “\(tree.name)”"),
                        tree: tree, template: nil, folder: folder, browser: browser,
                        undoManager: undoManager)
                case .renameInAllYears(let folder):
                    RenameInAllYearsSheet(
                        folder: folder, browser: browser, undoManager: undoManager)
                case .copy:
                    EmptyView()
                }
            }
            .alert(
                String(localized: "The folder’s structure cannot be copied"),
                isPresented: Binding(
                    get: { asked.problem != nil }, set: { if !$0 { asked.problem = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(asked.problem ?? "")
            }
            .task { await NameServices.templateList.load() }
    }
}
