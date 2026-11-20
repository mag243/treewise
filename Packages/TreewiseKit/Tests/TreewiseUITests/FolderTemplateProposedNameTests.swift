import Testing
import TreewiseCore
import TreewiseUI

/// The name Save Folder Structure as Template… proposes for a folder (ADR 0091): a year's
/// folder is named after the folder it is in, any other after itself.
@MainActor
@Suite struct FolderTemplateProposedNameTests {
    private let disk = VolumeID("disk")

    private func folder(_ path: String, in parent: String?) -> FileItem {
        let name = String(path.split(separator: "/").last ?? "")
        return FileItem(
            id: FileItem.ID(path), name: name, kind: .folder,
            parentID: parent.map { FileItem.ID($0) }, volume: disk)
    }

    @Test func aYearsFolderIsNamedAfterTheFolderItIsIn() {
        let year = folder("/Docs/Household/2025", in: "/Docs/Household")
        #expect(FolderTemplatesModel.proposedName(for: year) == "Household Year")
    }

    @Test func anyOtherFolderIsNamedAfterItself() {
        let project = folder("/Docs/Projects/Garden", in: "/Docs/Projects")
        #expect(FolderTemplatesModel.proposedName(for: project) == "Garden")
    }

    @Test func aFolderInsideAYearIsNamedAfterItself() {
        let tax = folder("/Docs/Household/2025/Tax", in: "/Docs/Household/2025")
        #expect(FolderTemplatesModel.proposedName(for: tax) == "Tax")
    }
}
