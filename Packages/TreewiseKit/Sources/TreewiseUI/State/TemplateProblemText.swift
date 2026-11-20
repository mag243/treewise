import Foundation
import TreewiseCore

/// What the sheets and Settings say, on the Mac and the iPad, about a template that cannot take a name or a change
/// (ADR 0091, ADR 0095, ADR 0096).
public enum TemplateProblemText {
    public static func text(for problem: FolderTree.Problem) -> String {
        switch problem {
        case .invalidName(let name):
            String(localized: "“\(name)” cannot be a folder’s name.", bundle: .module)
        case .hiddenName(let name):
            String(
                localized: "“\(name)” starts with a dot, so Finder would hide it.", bundle: .module)
        case .sameName(let name):
            String(localized: "There is already a folder “\(name)” here.", bundle: .module)
        case .tooManyFolders:
            String(
                localized: "A template holds at most \(FolderTree.mostFolders) folders.",
                bundle: .module)
        case .tooDeep:
            String(
                localized: "A template goes at most \(FolderTree.mostLevels) folders deep.",
                bundle: .module)
        case .invalidFormat(let name):
            String(
                localized: "“\(name)” holds a field with a format it does not take.",
                bundle: .module)
        case .numberBelowTop:
            String(
                localized:
                    "{seq} can only be in the top folder; write numbered folders as 01 Intake.",
                bundle: .module)
        case .intoItself: String(localized: "A folder cannot go into itself.", bundle: .module)
        case .repeatAtTop(let name):
            String(
                localized:
                    "“\(name)” repeats for each month, quarter or half, which only a folder below the top one can.",
                bundle: .module)
        case .repeatInRepeat(let name):
            String(
                localized:
                    "“\(name)” repeats inside a folder that repeats already; a folder can repeat once.",
                bundle: .module)
        }
    }

    public static func text(for problem: FolderTemplateSheetModel.Problem) -> String {
        switch problem {
        case .textNeeded:
            String(localized: "Type the text for the folders’ names.", bundle: .module)
        case .tree(let found): text(for: found)
        case .fieldWithoutValue:
            String(localized: "A field of the template has no value.", bundle: .module)
        }
    }

    public static func text(for problem: FolderTemplatesModel.Problem) -> String {
        switch problem {
        case .emptyName: String(localized: "A template needs a name.", bundle: .module)
        case .nameTaken(let name):
            String(localized: "Another template is named “\(name)”.", bundle: .module)
        case .tree(let found): text(for: found)
        case .file:
            String(
                localized: "The file is no template, or was made by a newer Treewise.",
                bundle: .module)
        case .notSaved: String(localized: "The template could not be saved.", bundle: .module)
        }
    }
}
