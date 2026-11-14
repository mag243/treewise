import Foundation
import TreewiseCore
import TreewiseUI

/// What the sheets and Settings say about a template that cannot take a name or a change
/// (ADR 0091, ADR 0095, ADR 0096).
enum TemplateProblemText {
    static func text(for problem: FolderTree.Problem) -> String {
        switch problem {
        case .invalidName(let name): String(localized: "“\(name)” cannot be a folder’s name.")
        case .hiddenName(let name):
            String(localized: "“\(name)” starts with a dot, so Finder would hide it.")
        case .sameName(let name): String(localized: "There is already a folder “\(name)” here.")
        case .tooManyFolders:
            String(localized: "A template holds at most \(FolderTree.mostFolders) folders.")
        case .tooDeep:
            String(localized: "A template goes at most \(FolderTree.mostLevels) folders deep.")
        case .invalidFormat(let name):
            String(localized: "“\(name)” holds a field with a format it does not take.")
        case .numberBelowTop:
            String(
                localized:
                    "{seq} can only be in the top folder; write numbered folders as 01 Intake.")
        case .intoItself: String(localized: "A folder cannot go into itself.")
        }
    }

    static func text(for problem: FolderTemplateSheetModel.Problem) -> String {
        switch problem {
        case .textNeeded: String(localized: "Type the text for the folders’ names.")
        case .tree(let found): text(for: found)
        case .addOnGaveNothing:
            String(
                localized:
                    "Folder Structure Templates gave no folders. Its trial or licence may have ended."
            )
        }
    }

    static func text(for problem: FolderTemplatesModel.Problem) -> String {
        switch problem {
        case .emptyName: String(localized: "A template needs a name.")
        case .nameTaken(let name): String(localized: "Another template is named “\(name)”.")
        case .tree(let found): text(for: found)
        case .file: String(localized: "The file is no template, or was made by a newer Treewise.")
        case .notSaved: String(localized: "The template could not be saved.")
        }
    }
}
